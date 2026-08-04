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


resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "29.21.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # The server and alertmanager PVCs bind WaitForFirstConsumer, so the volumes
  # are only cut once Auto Mode has scaled up a node to schedule onto. That is
  # a cold-start wait the 300s default does not cover.
  timeout = 900

  values = [file("${path.module}/helm-values/prometheus-values.yaml")]

  # The StorageClass is the hard dependency, not just the cluster: the release
  # waits on its PVCs, and with no default class they never bind.
  depends_on = [module.eks, kubernetes_storage_class_v1.gp3]
}

# grafana-community, not grafana.github.io: Grafana Labs handed this chart over
# to the community repo on 2026-01-30 and marked every release it published
# after that deprecated. The old repo's newest is 10.5.15; this is where the
# chart is actually maintained now.
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "grafana"
  version    = "12.10.2"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  values = [file("${path.module}/helm-values/grafana-values.yaml")]

  # Out of the values file and into state, so the generated password is not
  # sitting in a file in the repo. set_sensitive keeps it out of plan output.
  set_sensitive {
    name  = "adminPassword"
    value = random_password.grafana_admin.result
  }

  # ingress-nginx for the same webhook reason as argocd above. Prometheus is
  # listed because the provisioned datasource points at its Service; Grafana
  # will start without it, but the default datasource would be dead on arrival.
  depends_on = [
    module.eks,
    helm_release.ingress_nginx,
    helm_release.prometheus,
    kubernetes_storage_class_v1.gp3,
  ]
}