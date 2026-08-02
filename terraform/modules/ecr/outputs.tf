output "repository_url" {
  description = "URL of the repository (e.g. <acct>.dkr.ecr.<region>.amazonaws.com/<name>), used as the image source"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "Registry ID (AWS account ID) the repository lives in"
  value       = aws_ecr_repository.this.registry_id
}
