variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "roll_lower" {
  type    = string
  default = "23l-3059"
}

variable "owner_tag" {
  type    = string
  default = "23L-3059"
}

variable "bucket_name" {
  type    = string
  default = "cv-23l-3059"
}

variable "ssh_cidr" {
  type        = string
  description = "My public IP as /32 for SSH"
  default     = "116.90.119.246/32"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "budget_limit_usd" {
  type    = string
  default = "5.0"
}

variable "budget_email" {
  type    = string
  default = "l233059@lhr.nu.edu.pk"
}
