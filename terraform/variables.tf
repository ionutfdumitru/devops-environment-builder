variable "aws_region" {
  description = "AWS region used by the project"
  type        = string
  default     = "eu-west-1"
}

variable "ssh_allowed_cidr" {
  description = "Public IP allowed to connect through SSH"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "ami_id" {
  description = "ARM64 Ubuntu AMI used by the EC2 instance"
  type        = string
  default     = "ami-066d16f7e8255df5a"
}

variable "public_key_path" {
  description = "Path to the public SSH key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}