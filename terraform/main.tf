terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

}

##required_providers spune ce plugin foloseste Terraform
##provider "aws" configurează regiunea.
##Nu punem Access Key sau Secret Key in fisier. Terraform va folosi autentificarea AWS CLI deja configurata


data "aws_vpc" "default" {
  default = true
}
output "default_vpc_id" {
  value = data.aws_vpc.default.id
}


resource "aws_security_group" "project" {
  name        = "devops-environment-builder"
  description = "Security group for the DevOps project"
  vpc_id      = data.aws_vpc.default.id


  ingress {
    description = "SSH from current public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "project_security_group_id" {
  value = aws_security_group.project.id
}


resource "aws_key_pair" "project" {
  key_name   = "devops-environment-builder"
  public_key = file(pathexpand(var.public_key_path))
}

output "project_key_pair_name" {
  value = aws_key_pair.project.key_name
}



data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

resource "aws_instance" "project" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.public.ids)[0]
  vpc_security_group_ids = [aws_security_group.project.id]
  key_name               = aws_key_pair.project.key_name

  tags = {
    Name = "devops-environment-builder"
  }
}

output "project_instance_id" {
  value = aws_instance.project.id
}

output "project_instance_public_ip" {
  value = aws_instance.project.public_ip
}