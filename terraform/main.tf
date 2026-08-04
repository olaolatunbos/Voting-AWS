module "vpc" {
  source = "./modules/vpc"

  name                 = "eks-example"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = "example"
  kubernetes_version = "1.35"

  # Private subnets only — see the variable's description for why.
  subnet_ids = module.vpc.private_subnet_ids

  # olaolat.com — the zone the ingress hostnames live in.
  route53_hosted_zone_id = "Z07845832PA7LU4WK4CO"

  # kubectl access is granted here, not by IAM. Root is deliberately absent:
  # EKS will not accept the account root user as an access-entry principal.
  cluster_admin_principal_arns = ["arn:aws:iam::801497981564:user/eks-admin"]
}


module "vote-ecr" {
  source = "./modules/ecr"

  name = "voting-app/vote"
}

module "result-ecr" {
  source = "./modules/ecr"

  name = "voting-app/result"
}

module "worker-ecr" {
  source = "./modules/ecr"

  name = "voting-app/worker"
}