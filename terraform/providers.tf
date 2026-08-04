provider "aws" {
  region  = "eu-west-2"
  profile = "eks-admin"
}

# Auth mirrors `aws eks update-kubeconfig`: a short-lived token minted per
# apply, so nothing long-lived lands in state. AWS_PROFILE is pinned to
# eks-admin because the account root user cannot be an EKS access-entry
# principal and will be rejected by the API server.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "eu-west-2"]
      env = {
        AWS_PROFILE = "eks-admin"
      }
    }
  }
}
