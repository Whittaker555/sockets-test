output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.socketio_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.socketio_app.public_dns
}

output "application_url" {
  description = "URL to access the Socket.IO application"
  value       = "http://${aws_eip.socketio_eip.public_ip}:${var.app_port}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.project_name}-key ec2-user@${aws_eip.socketio_eip.public_ip}"
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.socketio_app.id
}