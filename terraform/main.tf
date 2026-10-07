terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "terraform_demo_sg" {
  name        = "terraform-demo-sg"
  description = "SG de practica para Fase 8 - Terraform"

  ingress {
    description = "SSH desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "terraform-demo-sg"
    Project = "devops-journey-fase8"
  }
}

resource "aws_instance" "terraform_demo" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.terraform_demo_sg.id]
  key_name               = var.key_pair_name

  tags = {
    Name    = "terraform-demo"
    Project = "devops-journey-fase8"
  }
}