data "terraform_remote_state" "cloud" {
  backend = var.remote_state_backend
  config  = var.remote_state_config
}

module "exafunction_kube" {
  source = "../.."

  cluster_name              = var.cluster_name
  cluster_oidc_issuer_url   = data.terraform_remote_state.cloud.outputs.exafunction_cluster.cluster_oidc_issuer_url
  cluster_oidc_provider_arn = data.terraform_remote_state.cloud.outputs.exafunction_cluster.oidc_provider_arn

  exadeploy_helm_values_path = "${path.module}/values.yaml"

  exafunction_api_key = var.api_key

  scheduler_image         = var.scheduler_image
  module_repository_image = var.module_repository_image
  runner_image            = var.runner_image

  module_repository_backend = "remote"
  s3_bucket_id              = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.s3_bucket_id
  s3_iam_user_access_key    = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.s3_iam_user_access_key
  s3_iam_user_secret_key    = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.s3_iam_user_secret_key
  rds_address               = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.rds_address
  rds_port                  = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.rds_port
  rds_username              = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.rds_username
  rds_password              = data.terraform_remote_state.cloud.outputs.exafunction_module_repo_backend.rds_password

  enable_grafana_public_address = true
  enable_prom_remote_write      = true
  prom_remote_write_username    = var.prom_remote_write_username
  prom_remote_write_password    = var.prom_remote_write_password
}
