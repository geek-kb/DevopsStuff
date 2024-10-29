variable "aws_region" {
  description = "AWS region"
  default     = "il-central-1"
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster"
  default     = "k8s-kubeadm"
  type        = string
}

variable "etcd_version" {
  description = "Version of etcd"
  default     = "v3.5.16"
  type        = string
}

variable "k8s_version" {
  description = "Version of k8s"
  default     = "v1.31.1"
  type        = string
}

variable "k8s_repo_version" {
  description = "Version of k8s repo"
  default     = "v1.31"
  type        = string
}

variable "containerd_version" {
  description = "Version of containerd"
  default     = "1.7.22"
  type        = string
}

variable "cni_version" {
  description = "Version of cni"
  default     = "v1.5.1"
  type        = string
}

variable "runtime_class_version" {
  description = "Version of runtime class runc"
  default     = "v1.2.0-rc.3"
  type        = string
}

variable "num_workers" {
  description = "Number of worker nodes"
  default     = 1
  type        = number
}

variable "worker_instance_type" {
  description = "Instance type for worker nodes"
  default     = "t3.small"
  type        = string
}

variable "num_controllers" {
  description = "Number of controller nodes"
  default     = 1
  type        = number
}

variable "controller_instance_type" {
  description = "Instance type for controller nodes"
  default     = "t3.medium"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  default     = "10.0.1.0/24"
  type        = string
}

variable "pod_network_cidr" {
  description = "CIDR block for the pod network"
  default     = "192.168.0.0/16"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the cluster"
  default     = "solepa.ws"
  type        = string
}

variable "email" {
  description = "Email address for the certificate"
  default     = "lel@lel.bz"
}

variable "local_user" {
  description = "Local user to set file owner on the keypair"
  default     = "itaig"
  type        = string
}

variable "lsb_release" {
  description = "LSB release"
  default     = "focal"
  type        = string
}