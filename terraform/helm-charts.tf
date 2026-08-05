resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.15.1"

  namespace        = "ingress-nginx"
  create_namespace = true

  values = [file("${path.module}/helm-values/ingress-nginx-values.yaml")]

  depends_on = [module.eks]
}


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

  depends_on = [module.eks, helm_release.ingress_nginx]
}



resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "88.1.5"
  namespace        = "monitoring"
  create_namespace = true

  timeout = 900

  values = [file("${path.module}/helm-values/kube-prometheus-stack-values.yaml")]


  set_sensitive {
    name  = "grafana.adminPassword"
    value = random_password.grafana_admin.result
  }

  depends_on = [
    module.eks,
    helm_release.ingress_nginx,
    kubernetes_storage_class_v1.gp3,
  ]
}