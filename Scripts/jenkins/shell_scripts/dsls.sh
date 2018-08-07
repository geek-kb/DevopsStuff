ssh -i /var/lib/jenkins/.ssh/deployment_rsa deploy@swarm-as-prod-02.naturalint.com "sudo docker service ls" | awk 'FNR > 1 {print $2}'
