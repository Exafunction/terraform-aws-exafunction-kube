# Exafunction AWS Kubernetes Module

<img src="https://raw.githubusercontent.com/Exafunction/terraform-aws-exafunction-kube/main/images/banner.png" alt="Exafunction x AWS x K8s" width="1280"/>

This repository provides a [Terraform](https://www.terraform.io/) module to set up the necessary [Kubernetes](https://kubernetes.io/) resources for an ExaDeploy system in an AWS [EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html). This includes deploying:
* [Kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret/) for the ExaDeploy system. This includes the Exafunction API key and optionally [S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) access credentials and [RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html) credentials needed for the persistent module repository backend.
* ExaDeploy [Helm](https://helm.sh/) chart responsible for bringing up ExaDeploy Kubernetes resources including the scheduler and module repository. See more details about the Helm chart [here](https://github.com/Exafunction/helm-charts/tree/main/charts/exadeploy).
* [Prometheus](https://prometheus.io/) Helm chart to create a Prometheus instance for ExaDeploy monitoring and a [Grafana](https://grafana.com/) instance for visualizing the metrics. See more details about the Helm chart [here](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).
* [NVIDIA Device Plugin](https://catalog.ngc.nvidia.com/orgs/nvidia/helm-charts/nvidia-device-plugin) Helm chart to enable GPU scheduling on the cluster. See more details about the Helm chart [here](https://github.com/NVIDIA/k8s-device-plugin/tree/master/deployments/helm/nvidia-device-plugin).
* [EKS Cluster Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html) used to autoscale nodes in the cluster.

Because this module uses the [Kubernetes Terraform provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs) to create Kubernetes resources, it **should not** be used in the same Terraform root module that creates the EKS cluster these resources are deployed in. In simpler terms, EKS cluster creation and deployment of Kubernetes resources in that cluster should be managed with separate `terraform apply` operations. See this section of the official [Kubernetes provider docs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources) or [this article](https://itnext.io/terraform-dont-use-kubernetes-provider-with-your-cluster-resource-d8ec5319d14a) describing the issue for more information.

## System Diagram

![System Diagram](https://raw.githubusercontent.com/Exafunction/terraform-aws-exafunction-kube/main/images/system_diagram.png)

This diagram shows a typical setup of ExaDeploy in EKS (and adjacent AWS resources). It consists of:
* An [RDS database](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html) and [S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) used as a persistent backend for the ExaDeploy module repository. These are not strictly required as the module repository also supports a local backend (which is not persistent between module repository restarts) but is recommended in production. This Terraform module is not responsible for creating these resources but must be configured to use them by providing the appropriate access credentials and addressing information (see [Configuration - Module Repository Backend](#module-repository-backend)). To create these resources, see [Exafunction/terraform-aws-exafunction-cloud/modules/module_repo_backend](https://github.com/Exafunction/terraform-aws-exafunction-cloud/modules/module_repo_backend).
* An EKS cluster used to run the ExaDeploy system. This Terraform module is not responsible for creating the cluster. To create it, see [Exafunction/terraform-aws-exafunction-cloud/modules/cluster](https://github.com/Exafunction/terraform-aws-exafunction-cloud/modules/cluster).
* The ExaDeploy Kubernetes resources, specifically the module repository and scheduler (which is responsible for managing runners). This Terraform module is responsible for creating these resources.
* A [Prometheus](https://prometheus.io/) instance for monitoring the ExaDeploy system (along with a Grafana server used to visualize these metrics, not pictured). This Terraform module is responsible for creating these resource.

## Usage
```hcl
module "exafunction_kube" {
  # Set the module source to use this module.
  source = "github.com/Exafunction/terraform-aws-exafunction-kube"

  # Set the cluster variables.
  cluster_name              = "cluster-abcd1234"
  cluster_oidc_issuer_url   = "https://oidc.eks.us-west-1.amazonaws.com/id/ABCD1234"
  cluster_oidc_provider_arn = "arn:aws:iam::123456781234:oidc-provider/oidc.eks.us-west-1.amazonaws.com/id/ABCD1234"

  # Set the Exafunction API Key.
  exafunction_api_key             = "12345678-1234-5678-1234-567812345678"

  # Set the ExaDeploy component images.
  scheduler_image = "123456781234.dkr.ecr.us-west-1.amazonaws.com/exafunction/scheduler:prod_abcd1234_1234567812"
  module_repository_image = "123456781234.dkr.ecr.us-west-1.amazonaws.com/exafunction/module_repository:prod_abcd1234_1234567812"
  runner_image = "123456781234.dkr.ecr.us-west-1.amazonaws.com/exafunction/runner@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"

  # Set the module repository backend.
  module_repository_backend = "local"

  # ...
}
```
See the configuration sections below as well as the [Inputs section](#inputs) and [variables.tf](https://github.com/Exafunction/terraform-aws-exafunction-kube/blob/main/variables.tf) file for a full list of configuration options.

See [examples/setup_exadeploy](https://github.com/Exafunction/terraform-aws-exafunction-kube/tree/main/examples/setup_exadeploy) for a working example of how to use this module.

## Cluster Configuration
While this module is not responsible for creating an [EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html), it does require information about an existing cluster to deploy resources to, including the name of the cluster and [OpenID Connect (OIDC)](https://openid.net/connect/) information associated with the cluster. For clusters created using [Exafunction/terraform-aws-exafunction-cloud/modules/cluster](https://github.com/Exafunction/terraform-aws-exafunction-cloud/modules/cluster), this information can be fetched using the `cluster_name`, `cluster_oidc_issuer_url`, and `oidc_provider_arn` module outputs.

## ExaDeploy Helm Chart Configuration
This Terraform module installs the [ExaDeploy Helm chart](https://github.com/Exafunction/helm-charts/tree/main/charts/exadeploy) in the EKS cluster (version set by `exadeploy_helm_chart_version`). [Helm](https://helm.sh/) is a package manager for Kubernetes that allows for easy installation of applications in a Kubernetes cluster. Helm charts can be configured by passing in [values](https://helm.sh/docs/chart_template_guide/values_files/) when installing through a values yaml file or command line arguments.

The configuration of the ExaDeploy Helm chart in this Terraform module is split between required values which are managed through dedicated Terraform variables and optional values which can be supplied using the `exadeploy_helm_values_path` variable (see [Optional Configuration](#optional-configuration)). These are all detailed in the sections below.

As a note, "required" variables in this sense means they must be set in order to install the Helm chart at all. Other "optional" values may be necessary to support specific infratructure configurations, toggle features, or maximize performance.

### Exafunction API Key
The Exafunction API key is a unique key used to identify the ExaDeploy system to Exafunction. The API key itself should be provided by Exafunction.

To set, see the `exafunction_api_key` and `exafunction_api_key_secret_name` variables.

### ExaDeploy Component Images
The Exafunction component images are the Docker images used to run the ExaDeploy system. These should be provided by Exafunction.

To set, see the `scheduler_image`, `module_repository_image`, and `runner_image` variables.

### Module Repository Backend
The module repository can be configured to use either a local backend on disk or a remote backend backed by an [RDS database](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html) and [S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html). The remote backend allows for persistence between module repository restarts and is recommended in production. For remote module backends created using [Exafunction/terraform-aws-exafunction-cloud/modules/module_repo_backend](https://github.com/Exafunction/terraform-aws-exafunction-cloud/modules/module_repo_backend), this information can be fetched from the module outputs.

To set, see the `module_repository_backend`, `rds_*`, and `s3_*` variables. If `module_repository_backend` is `local` then the other variables do not need to be specified. If `module_repository_backend` is `remote` then the other variables must all be non-null.

### Optional Configuration
While the above sections cover all the required values for the ExaDeploy Helm chart configuration, there are many additional values that can be set to customize the deployment. These values are specified in a yaml file (in [Helm values file format](https://helm.sh/docs/chart_template_guide/values_files/)) and passed to the Helm chart installation through the optional `exadeploy_helm_values_path` variable.

To see all the available values to be set, see the [ExaDeploy Helm chart](https://github.com/Exafunction/helm-charts/tree/main/charts/exadeploy). Note that Helm chart values corresponding to the required values above should not be set through this method as they will overriden (multiple Helm values specifications are automatically merged).

## Additional Resources

To learn more about Exafunction, visit the [Exafunction website](https://exafunction.com/).

For technical support or questions, check out our [community Slack](https://join.slack.com/t/exa-community/shared_invite/zt-1fx9dgcz5-aUg_UWW7zJYc_tYfw1TyNw).

For additional documentation about Exafunction including system concepts, setup guides, tutorials, API reference, and more, check out the [Exafunction documentation](https://docs.exafunction.com/).

For an equivalent repository used to set up ExaDeploy in a Kubernetes cluster on [Google Cloud Platform (GCP)](https://cloud.google.com/) instead of AWS, visit [`Exafunction/terraform-gcp-exafunction-kube`](https://github.com/Exafunction/terraform-gcp-exafunction-kube).

<!-- BEGIN_TF_DOCS -->
## Resources

| Name | Type |
|------|------|
| [helm_release.exadeploy](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kube_prometheus_stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.nvidia_device_plugin](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_cluster_role_binding.cluster_admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_secret.exafunction_api_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.rds_password](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.s3_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Exafunction EKS cluster. | `string` | n/a | yes |
| <a name="input_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#input\_cluster\_oidc\_issuer\_url) | The URL for the OpenID Connect identity provider associated with the EKS cluster. | `string` | n/a | yes |
| <a name="input_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#input\_cluster\_oidc\_provider\_arn) | The ARN of the OpenID Connect provider for the EKS cluster. | `string` | n/a | yes |
| <a name="input_exadeploy_helm_chart_version"></a> [exadeploy\_helm\_chart\_version](#input\_exadeploy\_helm\_chart\_version) | The version of the ExaDeploy Helm chart to use. | `string` | `"1.0.0"` | no |
| <a name="input_exadeploy_helm_values_path"></a> [exadeploy\_helm\_values\_path](#input\_exadeploy\_helm\_values\_path) | ExaDeploy Helm chart values yaml file path. | `string` | `null` | no |
| <a name="input_exafunction_api_key"></a> [exafunction\_api\_key](#input\_exafunction\_api\_key) | Exafunction API key used to identify the ExaDeploy system to Exafunction. | `string` | n/a | yes |
| <a name="input_exafunction_api_key_secret_name"></a> [exafunction\_api\_key\_secret\_name](#input\_exafunction\_api\_key\_secret\_name) | Exafunction API key Kubernetes secret name. This secret will be created by this module. | `string` | `"exafunction-api-key"` | no |
| <a name="input_module_repository_backend"></a> [module\_repository\_backend](#input\_module\_repository\_backend) | The backend to use for the ExaDeploy module repository. One of [local, remote]. If remote, `s3_*` and `rds_*` variables must be set. | `string` | `"local"` | no |
| <a name="input_module_repository_image"></a> [module\_repository\_image](#input\_module\_repository\_image) | Path to ExaDeploy module repository image. | `string` | n/a | yes |
| <a name="input_rds_address"></a> [rds\_address](#input\_rds\_address) | Address of the RDS database. | `string` | `null` | no |
| <a name="input_rds_password"></a> [rds\_password](#input\_rds\_password) | Password for RDS instance. This will be stored in the RDS password Kubernetes secret. | `string` | `null` | no |
| <a name="input_rds_password_secret_name"></a> [rds\_password\_secret\_name](#input\_rds\_password\_secret\_name) | RDS password Kubernetes secret name. This secret will be created by this module. | `string` | `"rds-password"` | no |
| <a name="input_rds_port"></a> [rds\_port](#input\_rds\_port) | Port of the RDS database. | `string` | `null` | no |
| <a name="input_rds_username"></a> [rds\_username](#input\_rds\_username) | Username for the RDS database. | `string` | `null` | no |
| <a name="input_runner_image"></a> [runner\_image](#input\_runner\_image) | Path to ExaDeploy runner image. | `string` | n/a | yes |
| <a name="input_s3_access_key_secret_name"></a> [s3\_access\_key\_secret\_name](#input\_s3\_access\_key\_secret\_name) | S3 access key Kubernetes secret name. This secret will be created by this module. | `string` | `"s3-access-key"` | no |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID for S3 bucket. | `string` | `null` | no |
| <a name="input_s3_iam_user_access_key"></a> [s3\_iam\_user\_access\_key](#input\_s3\_iam\_user\_access\_key) | Access key ID for the S3 IAM user. This will be stored in the S3 access key Kubernetes secret. | `string` | `null` | no |
| <a name="input_s3_iam_user_secret_key"></a> [s3\_iam\_user\_secret\_key](#input\_s3\_iam\_user\_secret\_key) | Secret access key for the S3 IAM user. This will be stored in the S3 access key Kubernetes secret. | `string` | `null` | no |
| <a name="input_scheduler_image"></a> [scheduler\_image](#input\_scheduler\_image) | Path to ExaDeploy scheduler image. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_autoscaler_helm_release_metadata"></a> [cluster\_autoscaler\_helm\_release\_metadata](#output\_cluster\_autoscaler\_helm\_release\_metadata) | Cluster autoscaler Helm release attributes. |
| <a name="output_exadeploy_helm_release_metadata"></a> [exadeploy\_helm\_release\_metadata](#output\_exadeploy\_helm\_release\_metadata) | ExaDeploy Helm release attributes. |
| <a name="output_nvidia_device_plugin_helm_release_metadata"></a> [nvidia\_device\_plugin\_helm\_release\_metadata](#output\_nvidia\_device\_plugin\_helm\_release\_metadata) | NVIDIA device plugin Helm release attributes. |
| <a name="output_prometheus_helm_release_metadata"></a> [prometheus\_helm\_release\_metadata](#output\_prometheus\_helm\_release\_metadata) | Prometheus Helm release attributes. |
<!-- END_TF_DOCS -->
