# -----------------------------
# Data for IRSA OIDC Thumbprint
# -----------------------------
data "tls_certificate" "oidc_thumbprint" {
  url = module.eks.oidc_issuer_url
}
