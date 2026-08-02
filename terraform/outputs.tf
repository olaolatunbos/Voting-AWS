# The eks-admin user is no longer managed here, so its name and password are
# no longer derivable from state. Sign-in URL is a constant, so it stays.
output "console_sign_in_url" {
  description = "IAM sign-in URL (sign in as eks-admin, not root)."
  value       = "https://801497981564.signin.aws.amazon.com/console"
}

output "kubeconfig_command" {
  description = "Point kubectl at the cluster (run as the eks-admin user)."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region eu-west-2"
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets hosting control-plane ENIs and Auto Mode nodes."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnets where internet-facing load balancers land."
  value       = module.vpc.public_subnet_ids
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "nat_gateway_public_ip" {
  description = "Egress IP for everything in the private subnets."
  value       = module.vpc.nat_gateway_public_ip
}
