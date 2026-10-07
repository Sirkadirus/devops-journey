variable "aws_region" {
  description = "Region de AWS donde desplegar"
  type        = string
  default     = "sa-east-1"
}

variable "ami_id" {
  description = "AMI de Amazon Linux o Ubuntu para la instancia"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Nombre del key pair existente en AWS para SSH"
  type        = string
}

variable "my_ip" {
  description = "Tu IP publica, en formato CIDR, para la regla SSH"
  type        = string
}