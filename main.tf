locals {
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler"
}

resource "kubernetes_cluster_role_binding" "cluster_admin" {
  metadata {
    name = "cluster-admin-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.k8s_service_account_name
    namespace = local.k8s_service_account_namespace
  }
}

resource "random_string" "irsa_role_name_prefix" {
  length  = 8
  special = false
  upper   = false
}

module "eks_cluster_autoscaler" {
  depends_on = [
    kubernetes_cluster_role_binding.cluster_admin,
  ]
  source  = "lablabs/eks-cluster-autoscaler/aws"
  version = "~> 2.0.0"

  cluster_name                     = var.cluster_name
  cluster_identity_oidc_issuer     = var.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = var.cluster_oidc_provider_arn
  namespace                        = local.k8s_service_account_namespace
  service_account_name             = local.k8s_service_account_name

  # Add a unique suffix to prevent collisions in the case of multiple instances of this module.
  irsa_role_name_prefix = "cluster-autoscaler-irsa-${random_string.irsa_role_name_prefix.result}"
}

resource "helm_release" "nvidia_device_plugin" {
  depends_on = [
    kubernetes_cluster_role_binding.cluster_admin,
  ]

  name       = "nvidia-device-plugin"
  chart      = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  version    = "0.12.2"
  namespace  = "kube-system"

  values = [yamlencode({
    nodeSelector = {
      "role"           = "runner"
      "nvidia.com/gpu" = "present"
    }
    tolerations = [
      {
        key      = "nvidia.com/gpu"
        operator = "Exists"
        effect   = "NoSchedule"
      },
      {
        key      = "dedicated"
        operator = "Equal"
        value    = "runner"
        effect   = "NoSchedule"
      }
    ]
  })]
}

data "aws_region" "current" {}

resource "helm_release" "exadeploy" {
  depends_on = [
    kubernetes_cluster_role_binding.cluster_admin,
    helm_release.nvidia_device_plugin,
    kubernetes_secret.rds_password,
    kubernetes_secret.s3_access,
    kubernetes_secret.exafunction_api_key,
  ]

  name       = "exadeploy"
  chart      = "exadeploy"
  repository = "https://exafunction.github.io/helm-charts"
  version    = var.exadeploy_helm_chart_version

  values = [
    var.exadeploy_helm_values_path == null ? "" : file(var.exadeploy_helm_values_path),
    yamlencode(
      {
        "exafunction" : {
          "apiKeySecret" : {
            "name" : var.exafunction_api_key_secret_name,
          },
        },
        "moduleRepository" : {
          "image" : var.module_repository_image,
          "nodeSelector" : {
            "role" = "module-repository",
          },
          "tolerations" : [{
            "key" : "dedicated",
            "operator" : "Equal",
            "value" : "module-repository",
            "effect" : "NoSchedule",
          }],
        },
        "scheduler" : {
          "image" : var.scheduler_image,
          "nodeSelector" : {
            "role" = "scheduler",
          },
          "tolerations" : [{
            "key" : "dedicated",
            "operator" : "Equal",
            "value" : "scheduler",
            "effect" : "NoSchedule",
          }],
        },
        "runner" : {
          "image" : var.runner_image,
          "nodeSelector" : {
            "role" = "runner",
          },
          "tolerations" : [{
            "key" : "dedicated",
            "operator" : "Equal",
            "value" : "runner",
            "effect" : "NoSchedule",
          }],
        },
      }
    ),
    var.module_repository_backend == "local" ? yamlencode(
      {
        "moduleRepository" : {
          "backend" : {
            "type" : "local",
          },
        }
      }
      ) : yamlencode({
        "moduleRepository" : {
          "backend" : {
            "type" : "remote",
            "remote" : {
              "postgres" : {
                "database" : "postgres",
                "host" : var.rds_address,
                "port" : var.rds_port,
                "user" : var.rds_username,
                "passwordSecret" : {
                  "name" : var.rds_password_secret_name,
                },
              }
              "dataBackend" : "s3",
              "s3" : {
                "region" : data.aws_region.current.name,
                "bucket" : var.s3_bucket_id,
                "awsAccessKeySecret" : {
                  "name" : var.s3_access_key_secret_name,
                },
              },
            },
          },
        },
    })
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "prometheus"
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  version          = "39.11.0"
  values           = [file("${path.module}/helm_prometheus.yaml")]
  namespace        = "prometheus"
  create_namespace = true
}
