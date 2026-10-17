output "jenkins_url" {
  value = "http://${aws_instance.controller.public_ip}:8080"
}

output "controller_public_ip" {
  value = aws_instance.controller.public_ip
}

output "agent_private_ips" {
  value = aws_instance.agent[*].private_ip
}

output "backup_bucket" {
  value = aws_s3_bucket.backup.bucket
}

output "agent_ssh_private_key" {
  description = "Paste into Jenkins credential 'SSH Username with private key' (username: jenkins)"
  value       = tls_private_key.agent_ssh.private_key_openssh
  sensitive   = true
}
