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

variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet publica"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ de la subnet"
  type        = string
  default     = "sa-east-1b"
}

variable "backups_bucket_name" {
  description = "Nombre del bucket S3 de backups (unico a nivel global en AWS)"
  type        = string
  default     = "devops-journey-backups-tf-kadirus01"
}