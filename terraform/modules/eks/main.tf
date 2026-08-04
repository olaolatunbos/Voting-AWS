resource "aws_eks_cluster" "example" {
  name = var.cluster_name

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  bootstrap_self_managed_addons = false

  compute_config {
    enabled       = true
    node_pools    = var.node_pools
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    subnet_ids              = var.subnet_ids
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,
  ]
}

resource "aws_eks_access_entry" "cluster_admin" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.example.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = aws_eks_access_entry.cluster_admin

  cluster_name  = aws_eks_cluster.example.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# The cluster always publishes an OIDC issuer; this registers it with IAM so
# STS will federate ServiceAccount tokens into roles (IRSA). Equivalent to
# `eksctl utils associate-iam-oidc-provider --approve`.
#
# thumbprint_list is omitted, not set to []: IAM stopped verifying it for
# AWS-hosted issuers and fills it in itself, so the attribute is computed.
# An explicit [] is not the same as absent — it plans a diff on every run
# trying to strip the value AWS wrote.
resource "aws_iam_openid_connect_provider" "cluster" {
  url            = aws_eks_cluster.example.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_policy" "policy" {
  name        = "external-dns-policy"
  path        = "/"
  description = "Policy for external-dns to manage Route53 records"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ],
        Effect   = "Allow"
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      # ListHostedZones is account-scoped, not zone-scoped: Route53 rejects any
      # resource ARN on it, so it needs "*" and cannot be folded into the
      # statement above. external-dns calls it on startup to resolve
      # domainFilters to zone IDs, so without it nothing else is even reached.
      {
        Action   = ["route53:ListHostedZones"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "example" {
  name               = "eks-pod-identity-example"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.example.name
}

# Must match the ServiceAccount the external-dns chart creates, which takes the
# release name. A mismatch is silent: the pod simply gets no credentials.
resource "aws_eks_pod_identity_association" "example" {
  cluster_name    = aws_eks_cluster.example.name
  namespace       = "default"
  service_account = "external-dns"
  role_arn        = aws_iam_role.example.arn
}

# cert-manager needs Route53 write access of its own for the ACME DNS-01
# solver: it creates a _acme-challenge TXT record, waits for Let's Encrypt to
# read it, then deletes it. This is separate from external-dns's access — they
# write different records and neither implies the other.
resource "aws_iam_policy" "cert_manager" {
  name        = "cert-manager-route53"
  path        = "/"
  description = "Policy for cert-manager to solve ACME DNS-01 challenges in Route53"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"
      },
      # cert-manager polls this after submitting a change to learn when Route53
      # has propagated it, before telling ACME the record is ready. Change IDs
      # are not knowable in advance, hence the wildcard.
      {
        Action   = ["route53:GetChange"]
        Effect   = "Allow"
        Resource = "arn:aws:route53:::change/*"
      },
      # Only reached when an Issuer omits hostedZoneID and cert-manager has to
      # find the zone by name. Cheap to allow, and avoids a confusing failure
      # if a future Issuer leaves it out.
      {
        Action   = ["route53:ListHostedZonesByName"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "cert_manager" {
  name               = "cert-manager-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  policy_arn = aws_iam_policy.cert_manager.arn
  role       = aws_iam_role.cert_manager.name
}

# "certmanager-cert-manager", not "cert-manager": the chart prefixes the release
# name unless it already contains the chart name, and the release is "certmanager".
resource "aws_eks_pod_identity_association" "cert_manager" {
  cluster_name    = aws_eks_cluster.example.name
  namespace       = "cert-manager"
  service_account = "certmanager-cert-manager"
  role_arn        = aws_iam_role.cert_manager.arn
}

resource "aws_iam_role" "node" {
  name = "eks-auto-node-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodeMinimalPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryPullOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role" "cluster" {
  name = "eks-cluster-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSComputePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSBlockStoragePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSLoadBalancingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSNetworkingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.cluster.name
}
