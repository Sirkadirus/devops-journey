output "instance_public_ip" {
  description = "IP publica de la instancia creada"
  value       = aws_instance.terraform_demo.public_ip
}

output "instance_id" {
  description = "ID de la instancia creada"
  value       = aws_instance.terraform_demo.id
}