output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered to match availability_zones."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered to match availability_zones."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_public_ip" {
  description = "Egress IP for everything in the private subnets."
  value       = aws_eip.nat.public_ip
}
