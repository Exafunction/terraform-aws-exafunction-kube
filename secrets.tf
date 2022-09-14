resource "kubernetes_secret" "exafunction_api_key" {
  metadata {
    name = var.exafunction_api_key_secret_name
  }
  data = {
    api_key = var.exafunction_api_key
  }
}

resource "kubernetes_secret" "rds_password" {
  count = var.module_repository_backend == "local" ? 0 : 1
  metadata {
    name = var.rds_password_secret_name
  }
  data = {
    postgres_password = var.rds_password
  }
}

resource "kubernetes_secret" "s3_access" {
  count = var.module_repository_backend == "local" ? 0 : 1
  metadata {
    name = var.s3_access_key_secret_name
  }
  data = {
    access_key = var.s3_iam_user_access_key
    secret_key = var.s3_iam_user_secret_key
  }
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "kubernetes_secret" "prom_remote_write_basic_auth" {
  depends_on = [
    kubernetes_namespace.prometheus,
  ]

  count = var.enable_prom_remote_write ? 1 : 0
  metadata {
    name      = var.prom_remote_write_basic_auth_secret_name
    namespace = "prometheus"
  }
  data = {
    user     = var.prom_remote_write_username
    password = var.prom_remote_write_password
  }
}
