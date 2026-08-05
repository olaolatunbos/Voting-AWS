# Auto Mode enables the block storage capability (storage_config in
# modules/eks/main.tf) but does not create a StorageClass to go with it, and
# unlike self-managed EKS there is no "gp2" class installed by an addon. Until
# something claims the default annotation, every PVC in the cluster sits
# Pending forever — which is how the Prometheus and Grafana volumes would fail.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.eks.amazonaws.com"

  volume_binding_mode = "WaitForFirstConsumer"

  # Volumes are resizable in place; shrinking still is not possible.
  allow_volume_expansion = true

  reclaim_policy = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}

resource "random_password" "grafana_admin" {
  length = 24
  # Grafana's login form is fine with symbols, but the value also travels
  # through shell one-liners like the one above often enough to be worth it.
  special = false
}
