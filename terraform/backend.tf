terraform {
  # State locking is native to the S3 backend (use_lockfile) — it writes a
  # .tflock object beside the state and relies on S3 conditional writes.
  # No DynamoDB table; that mechanism is deprecated.
  backend "s3" {
    bucket       = "eks-project-tfstate-801497981564"
    key          = "eks-project/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
