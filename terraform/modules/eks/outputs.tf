output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.example.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.example.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.example.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA cert for the API server."
  value       = aws_eks_cluster.example.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS-managed security group attached to control-plane ENIs and nodes."
  value       = aws_eks_cluster.example.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "IAM role assumed by Auto Mode nodes."
  value       = aws_iam_role.node.arn
}
