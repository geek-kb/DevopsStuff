data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.cluster_name}-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # route {
  #     ipv6_cidr_block        = "::/0"
  #     egress_only_gateway_id = aws_internet_gateway.main.id
  # }

  tags = {
    Name = "${var.cluster_name}-rt"
  }
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  security_group_id = aws_security_group.main.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.main.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.main.id
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.main.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  security_group_id = aws_security_group.main.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "vpc_cidr" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = "all"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "pod_network_cidr" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = "all"
  cidr_ipv4         = var.pod_network_cidr
}

resource "aws_lb" "main" {
  name                             = "${var.cluster_name}-nlb"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = [aws_subnet.main.id]
  enable_cross_zone_load_balancing = false
  enable_deletion_protection       = false
  enable_http2                     = true
  idle_timeout                     = 60
  tags = {
    Name = "${var.cluster_name}-nlb"
  }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.cluster_name}-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    port = 6443
  }

  tags = {
    Name = "${var.cluster_name}-tg"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "tls_private_key" "tls_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.cluster_name}-key"
  public_key = tls_private_key.tls_private_key.public_key_openssh
}

resource "local_file" "key_pair" {
  depends_on      = [aws_key_pair.key_pair]
  content         = tls_private_key.tls_private_key.private_key_pem
  filename        = "${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "controller" {
  count                       = var.num_controllers
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.controller_instance_type
  key_name                    = aws_key_pair.key_pair.key_name
  subnet_id                   = aws_subnet.main.id
  security_groups             = [aws_security_group.main.id]
  associate_public_ip_address = true
  private_ip                  = cidrhost("${var.subnet_cidr}", 10 + count.index * 10)
  tags = {
    Name = "${var.cluster_name}-controller-${count.index}"
  }
  metadata_options {
    instance_metadata_tags = "enabled"
  }
}

resource "aws_instance" "worker" {
  count                       = var.num_workers
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  key_name                    = aws_key_pair.key_pair.key_name
  subnet_id                   = aws_subnet.main.id
  security_groups             = [aws_security_group.main.id]
  associate_public_ip_address = true
  private_ip                  = cidrhost("${var.subnet_cidr}", 100 + count.index * 10)
  tags = {
    Name = "${var.cluster_name}-worker-${count.index}"
  }
  metadata_options {
    instance_metadata_tags = "enabled"
  }
}

resource "local_file" "ec2_controller_provision_script" {
  filename = "/tmp/controller_provision.sh"
  content  = <<-EOF
#!/bin/bash
sudo mkdir -p -m 755 /etc/apt/keyrings
release=$(lsb_release -cs)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $release stable"
curl -fsSL https://pkgs.k8s.io/core:/stable:/${var.k8s_repo_version}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${var.k8s_repo_version}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Waiting for apt lock...'; sleep 20; done
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 20; done
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg kubelet kubeadm kubectl helm docker.io -y
sudo usermod -aG docker ubuntu       
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable docker.service
sudo systemctl enable kubelet.service
sudo systemctl start docker.service
sudo systemctl start kubelet.service
mkdir -p /home/ubuntu/.kube
echo 'alias k=$(which kubectl)' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
source ~/.bashrc
EOF
}

resource "null_resource" "upload_controller_provision_script" {
  count = var.num_controllers < 2 ? 1 : var.num_controllers
  depends_on = [
    aws_instance.controller,
    local_file.key_pair,
    local_file.ec2_controller_provision_script
  ]
  triggers = {
    instance_ids = join(",", aws_instance.controller[*].id)
  }

  provisioner "local-exec" {
    command = <<EOT
        sleep 120
        scp -i ${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem /tmp/controller_provision.sh ubuntu@${aws_instance.controller[count.index].public_ip}:/tmp/controller_provision.sh
EOT
  }
}

resource "null_resource" "run_controller_provision_script" {
  count      = var.num_controllers < 2 ? 1 : var.num_controllers
  depends_on = [null_resource.upload_controller_provision_script]
  triggers = {
    instance_ids = join(",", aws_instance.controller[*].id)
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[count.index].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      "chmod +x /tmp/controller_provision.sh",
      "/tmp/controller_provision.sh",
      "sudo hostnamectl set-hostname ${var.cluster_name}-controller-${count.index}"
    ]
  }
}

resource "local_file" "ec2_worker_provision_script" {
  filename = "/tmp/worker_provision.sh"
  content  = <<-EOF
#!/bin/bash
sudo apt-get update
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${var.k8s_repo_version}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${var.k8s_repo_version}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Waiting for apt lock...'; sleep 20; done
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 20; done
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
release=$(lsb_release -cs)
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $release stable"
sudo apt-get update
while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Waiting for apt lock...'; sleep 20; done
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 20; done
sudo apt-get install docker.io -y
sudo usermod -aG docker ubuntu
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Waiting for apt lock...'; sleep 20; done
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 20; done       
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable docker.service
sudo systemctl enable kubelet.service
sudo systemctl start docker.service
sudo systemctl start kubelet.service
EOF
}

resource "null_resource" "upload_worker_provision_script" {
  count = var.num_workers < 2 ? 1 : var.num_workers
  depends_on = [
    aws_instance.worker,
    local_file.key_pair,
    local_file.ec2_worker_provision_script,
    null_resource.upload_controller_provision_script
  ]
  triggers = {
    instance_ids = join(",", aws_instance.worker[*].id)
  }

  provisioner "local-exec" {
    command = <<EOT
        sleep 120
        scp -i ${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem /tmp/worker_provision.sh ubuntu@${aws_instance.worker[count.index].public_ip}:/tmp/worker_provision.sh
EOT
  }
}

resource "null_resource" "run_worker_provision_script" {
  count = var.num_workers < 2 ? 1 : var.num_workers
  depends_on = [
    null_resource.upload_worker_provision_script,
    aws_instance.controller
  ]
  triggers = {
    instance_ids = join(",", aws_instance.worker[*].id)
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.worker[count.index].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      "chmod +x /tmp/worker_provision.sh",
      "/tmp/worker_provision.sh",
      "sudo hostnamectl set-hostname ${var.cluster_name}-worker-${count.index}"
    ]
  }
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

resource "null_resource" "kubeadm_init" {
  depends_on = [
    aws_instance.controller,
    null_resource.run_controller_provision_script
  ]
  triggers = {
    instance_id = aws_instance.controller[0].id
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      "sudo kubeadm init --pod-network-cidr=${var.pod_network_cidr}",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "sudo echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc",
      "sudo kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh",
      "sudo chown ubuntu:ubuntu /tmp/kubeadm_join_command.sh"
    ]
  }
}

# resource "null_resource" "get_kubeadm_join_command" {
#   depends_on = [
#     aws_instance.controller,
#     null_resource.run_worker_provision_script,
#     null_resource.run_controller_provision_script,
#     null_resource.kubeadm_init
#   ]
#   triggers = {
#     instance_id = aws_instance.controller[0].id
#   }

#   provisioner "remote-exec" {
#     connection {
#       type        = "ssh"
#       host        = aws_instance.controller[0].public_ip
#       user        = "ubuntu"
#       private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#     }

#     inline = [
#       # Grep the kubeadm join command from the init output
#       "kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh"
#     ]
#   }
# }

resource "null_resource" "download_kubeadm_join_command" {
  depends_on = [
    null_resource.run_worker_provision_script,
    null_resource.kubeadm_init
  ]

  provisioner "local-exec" {
    command = "scp -i ${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem ubuntu@${aws_instance.controller[0].public_ip}:/tmp/kubeadm_join_command.sh /tmp/kubeadm_join_command.sh"
  }
}

resource "null_resource" "upload_kubeadm_join_command_to_workers" {
  count = var.num_workers
  depends_on = [
    null_resource.kubeadm_init,
    null_resource.run_worker_provision_script
  ]

  provisioner "local-exec" {
    command = "scp -i ${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem /tmp/kubeadm_join_command.sh ubuntu@${aws_instance.worker[*].public_ip}:/tmp/kubeadm_join_command.sh"
  }
}

output "controller_public_ip" {
  value = aws_instance.controller[0].public_ip
}

resource "null_resource" "kubeadm_join_worker" {
  count      = var.num_workers
  depends_on = [null_resource.kubeadm_init]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.worker[count.index].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Use the join command to connect the worker node to the cluster
      "sudo chown ubuntu:ubuntu /tmp/kubeadm_join_command.sh",
      "sudo /tmp/kubeadm_join_command.sh --ignore-preflight-errors=all",
      "rm -f /tmp/kubeadm_join_command.sh"
    ]
  }
}

resource "null_resource" "get_kubeconfig" {
  depends_on = [
    local_file.ec2_controller_provision_script,
    null_resource.kubeadm_init
  ]
  triggers = {
    instance_id = aws_instance.controller[0].id
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Copy the kubeconfig file to the local machine
      "sudo cp /etc/kubernetes/admin.conf ~ubuntu/.kube/config",
      "sudo chown ubuntu:ubuntu ~ubuntu/.kube/config",
      "cp ~/.kube/config /tmp/${var.cluster_name}-admin.conf",
    ]
  }
}

resource "null_resource" "output_kubeconfig" {
  depends_on = [
    null_resource.get_kubeconfig
  ]
  provisioner "local-exec" {
    command = <<EOT
      scp -i ${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem ubuntu@${aws_instance.controller[0].public_ip}:/home/ubuntu/.kube/config ~/.kube/${var.cluster_name}-admin.conf
      sudo chown ${var.local_user}:staff ~/.kube/${var.cluster_name}-admin.conf
EOT
  }
}

resource "null_resource" "install_calico" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Calico CNI
      "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
    ]
  }
}

resource "null_resource" "install_metrics_server" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Metrics Server
      "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    ]
  }
}

resource "null_resource" "install_dashboard" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Kubernetes Dashboard
      "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml",
      "kubectl create secret generic admin-user --namespace kubernetes-dashboard --type kubernetes.io/service-account-token --from-literal=annotations.kubernetes.io/service-account.name='admin-user'"
    ]
  }
}

resource "null_resource" "create_dashboard_user" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Create a service account for the dashboard
      "kubectl apply -f - <<EOF\napiVersion: v1\nkind: ServiceAccount\nmetadata:\n  name: admin-user\n  namespace: kubernetes-dashboard\nEOF",
      "kubectl apply -f - <<EOF\napiVersion: rbac.authorization.k8s.io/v1\nkind: ClusterRoleBinding\nmetadata:\n  name: admin-user\nroleRef:\n  apiGroup: rbac.authorization.k8s.io\n  kind: ClusterRole\n  name: cluster-admin\nsubjects:\n- kind: ServiceAccount\n  name: admin-user\n  namespace: kubernetes-dashboard\nEOF",
      "kubectl get secret -n kubernetes-dashboard $(kubectl get serviceaccount admin-user -n kubernetes-dashboard -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode > /tmp/dashboard_token.txt"
    ]
  }
}

# data "external" "get_dashboard_token" {
#     depends_on = [null_resource.create_dashboard_user]

#     program = ["ssh", "-i", "${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem", "ubuntu@${aws_instance.controller[0].public_ip}", "cat /tmp/dashboard_token.txt"]
# }

# output "dashboard_url" {
#     depends_on = [null_resource.create_dashboard_user]
#     value = "http://${aws_instance.controller[0].public_ip}:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
# }

# output "dashboard_token" {
#     depends_on = [null_resource.create_dashboard_user]
#     value      = data.external.get_dashboard_token.result
# }

resource "null_resource" "install_nginx_ingress_controller" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Nginx Ingress Controller
      "sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/aws/deploy.yaml"
    ]
  }
}

# resource "null_resource" "install_cert_manager" {
#     depends_on = [null_resource.get_kubeconfig]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Install Cert Manager
#             "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml"
#         ]
#     }
# }

# resource "null_resource" "install_lets_encrypt" {
#     depends_on = [null_resource.get_kubeconfig]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Install Let's Encrypt Issuer
#             "kubectl apply -f - <<EOF\napiVersion: cert-manager.io/v1\nkind: ClusterIssuer\nmetadata:\n  name: letsencrypt-prod\nspec:\n  acme:\n    server: https://acme-v02.api.letsencrypt.org/directory\n    email: ${var.email}\n    privateKeySecretRef:\n      name: letsencrypt-prod\n    solvers:\n    - http01:\n        ingress:\n          class: nginx\nEOF"
#         ]
#     }
# }

# resource "null_resource" "install_certbot" {
#     depends_on = [null_resource.get_kubeconfig]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Install Certbot
#             "sudo apt-get install -y certbot",
#             "sudo certbot certonly --standalone -d ${var.domain_name} --agree-tos --email ${var.email} --non-interactive"
#         ]
#     }
# }

# resource "null_resource" "create_certbot_cert_secret" {
#     depends_on = [null_resource.install_certbot]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Create Certbot Cert Secret
#             "kubectl create secret tls ${var.domain_name}-tls --key /etc/letsencrypt/live/${var.domain_name}/privkey.pem --cert /etc/letsencrypt/live/${var.domain_name}/fullchain.pem"
#         ]
#     }
# }

# resource "null_resource" "create_ingress" {
#     depends_on = [null_resource.create_certbot_cert_secret]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Create Ingress
#             "kubectl apply -f - <<EOF\napiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n  name: ${var.domain_name}-ingress\n  namespace: default\n  annotations:\n    kubernetes.io/ingress.class: nginx\n    cert-manager.io/cluster-issuer: letsencrypt-dev\nspec:\n  tls:\n  - hosts:\n    - ${var.domain_name}\n    secretName: ${var.domain_name}-tls\n  rules:\n  - host: ${var.domain_name}\n    http:\n      paths:\n      - path: /\n        pathType: Prefix\n        backend:\n          service:\n            name: kubernetes-dashboard\n            port:\n              number: 443\nEOF"
#         ]
#     }
# }

# resource "null_resource" "output_ingress" {
#     depends_on = [null_resource.create_ingress]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Output Ingress
#             "kubectl get ingress"
#         ]
#     }
# }

# data "external" "get_ingress" {
#     depends_on = [null_resource.create_ingress]

#     program = ["ssh", "-i", "${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem", "ubuntu@${aws_instance.controller[0].public_ip}", "kubectl get ingress ${var.domain_name}-ingress --no-headers | awk '{print $1}'"]
# }

# output "ingress" {
#     value = data.external.get_ingress.result
# }

resource "null_resource" "install_helm" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Helm
      "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3",
      "chmod 700 get_helm.sh",
      "sudo ./get_helm.sh"
    ]
  }
}

resource "null_resource" "install_prometheus" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Prometheus
      "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts",
      "helm repo update",
      "kubectl create namespace monitoring",
      "helm install prometheus prometheus-community/prometheus --namespace monitoring"
    ]
  }
}

resource "null_resource" "install_grafana" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Grafana
      "helm repo add grafana https://grafana.github.io/helm-charts",
      "helm repo update",
      "kubectl create namespace monitoring",
      "helm install grafana grafana/grafana --namespace monitoring"
    ]
  }
}

# data "external" "get_grafana_admin_password" {
#     depends_on = [null_resource.install_grafana]

#     program = ["ssh", "-i", "${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem", "ubuntu@${aws_instance.controller[0].public_ip}", "kubectl get secret --namespace monitoring grafana -o jsonpath='{.data.admin-password}' | base64 --decode"]
# }

output "grafana_url" {
  value = "http://${aws_instance.controller[0].public_ip}:3000"
}

# output "grafana_admin_password" {
#     value = data.external.get_grafana_admin_password.result
# }

# resource "null_resource" "install_efk" {
#     depends_on = [null_resource.get_kubeconfig]

#     provisioner "remote-exec" {
#         connection {
#             type     = "ssh"
#             host     = "${aws_instance.controller[0].public_ip}"
#             user     = "ubuntu"
#             private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
#         }

#         inline = [
#             # Install EFK
#             "kubectl create namespace logging",
#             "helm repo add elastic https://helm.elastic.co",
#             "helm repo update",
#             "helm install elasticsearch elastic/elasticsearch --namespace logging",
#             "helm install kibana elastic/kibana --namespace logging",
#             "helm install fluent-bit stable/fluent-bit --namespace logging"
#         ]
#     }
# }

# data "external" "get_kibana_password" {
#     depends_on = [null_resource.install_efk]

#     program = ["ssh", "-i", "${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem", "ubuntu@${aws_instance.controller[0].public_ip}", "kubectl get secret --namespace logging kibana-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode"]
# }

# output "kibana_url" {
#     value = "http://${aws_instance.controller[0].public_ip}:5601"
# }

# output "kibana_password" {
#     value = data.external.get_kibana_password.result
# }

resource "null_resource" "install_argocd" {
  depends_on = [null_resource.get_kubeconfig]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.controller[0].public_ip
      user        = "ubuntu"
      private_key = file("${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem")
    }

    inline = [
      # Install Argo CD
      "kubectl create namespace argocd",
      "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    ]
  }
}

# data "external" "get_argocd_password" {
#     depends_on = [null_resource.install_argocd]

#     program = ["ssh", "-i", "${pathexpand("~")}/.ssh/${var.cluster_name}-key.pem", "ubuntu@${aws_instance.controller[0].public_ip}", "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode"]
# }

output "argocd_url" {
  value = "http://${aws_instance.controller[0].public_ip}:8080"
}

# output "argocd_password" {
#     value = data.external.get_argocd_password.result
# }
