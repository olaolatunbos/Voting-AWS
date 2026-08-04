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

output "oidc_provider_arn" {
  description = "IAM OIDC provider for the cluster. Goes in the Federated principal of an IRSA trust policy."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = <<-EOT
    Issuer with the https:// scheme stripped. IRSA trust-policy conditions key
    off this form: the condition variable is "<this>:sub" and the value is
    "system:serviceaccount:<namespace>:<serviceaccount>".
  EOT
  value       = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
}
