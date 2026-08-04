variable "cluster_name" {
  description = "Name of the EKS cluster. Also used to name its IAM roles."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane."
  type        = string
}

variable "subnet_ids" {
  description = <<-EOT
    Subnets for control-plane ENIs and Auto Mode nodes. Pass private subnets
    only — internet-facing load balancers are placed by subnet tag, not from
    this list, so adding public subnets here only risks nodes with public IPs.
  EOT
  type        = list(string)
}

variable "node_pools" {
  description = "Auto Mode built-in node pools to enable."
  type        = list(string)
  default     = ["general-purpose"]
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API is reachable from the internet."
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Whether the Kubernetes API is reachable from inside the VPC."
  type        = bool
  default     = true
}

variable "route53_hosted_zone_id" {
  description = <<-EOT
    Zone cert-manager may write ACME DNS-01 challenge records into. Scoped to a
    single zone rather than hostedzone/* because this grants record-write access
    to a live public domain.
  EOT
  type        = string
}

variable "cluster_admin_principal_arns" {
  description = <<-EOT
    IAM users/roles granted cluster-admin via EKS access entries. Under
    authentication_mode = "API" this is the only path to Kubernetes RBAC —
    IAM AdministratorAccess alone gets you nothing from kubectl. The account
    root user cannot be listed here; EKS rejects it as an access-entry
    principal.
  EOT
  type        = list(string)
  default     = []
}
