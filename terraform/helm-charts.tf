resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.15.1"

  namespace        = "ingress-nginx"
  create_namespace = true

  values = [file("${path.module}/helm-values/ingress-nginx-values.yaml")]

  # The provider authenticates against the cluster, but that is a provider-level
  # reference; the release itself still needs the cluster to exist first.
  depends_on = [module.eks]
}


# Upstream's chart, not Bitnami's: Bitnami pulled versioned tags from its
# public Docker Hub catalog, so the image its chart pins now 404s.
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = "1.21.1"
  namespace  = "default"

  values     = [file("${path.module}/helm-values/external-dns-values.yaml")]
  depends_on = [module.eks]
}

resource "helm_release" "cert_manager" {
  name             = "certmanager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.21.1"
  namespace        = "cert-manager"
  create_namespace = true

  values     = [file("${path.module}/helm-values/cert-manager-values.yaml")]
  depends_on = [module.eks]
}


resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.2.2"
  namespace        = "argocd"
  timeout          = 600
  create_namespace = true
  values           = [file("${path.module}/helm-values/argocd-values.yaml")]

  # ingress-nginx must be up first, not just the cluster: this chart creates an
  # Ingress, and ingress-nginx runs a validating webhook the API server calls on
  # every Ingress write. Created in parallel, the webhook has no endpoints yet
  # and the Ingress is rejected, failing the whole release.
  depends_on = [module.eks, helm_release.ingress_nginx]
}