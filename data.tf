# -----------------------------
# Data for IRSA OIDC Thumbprint
# -----------------------------
data "tls_certificate" "oidc_thumbprint" {
  url = try(module.eks.oidc_issuer_url, null)
}
