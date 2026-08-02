variable "name" {
  description = "Name prefix applied to every resource in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "AZs to spread subnets across. Must be the same length as the subnet CIDR lists."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per availability zone."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "public_subnet_cidrs must have one entry per availability zone."
  }
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per availability zone."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "private_subnet_cidrs must have one entry per availability zone."
  }
}
