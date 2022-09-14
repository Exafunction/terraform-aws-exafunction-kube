variable "region" {
  description = "Region to bring up Exafunction infrastructure in."
  type        = string
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster."
  type        = string
}

variable "api_key" {
  description = "Exafunction API key"
  type        = string
}

variable "scheduler_image" {
  description = "Path to ExaDeploy scheduler image."
  type        = string
}

variable "module_repository_image" {
  description = "Path to ExaDeploy module repository image."
  type        = string
}

variable "runner_image" {
  description = "Path to ExaDeploy runner image."
  type        = string
}

variable "remote_state_backend" {
  description = "The remote state backend to use."
  type        = string
}

variable "remote_state_config" {
  description = "The configuration of the remote backend."
  type        = map(string)
}

variable "prom_remote_write_username" {
  description = "User (e.g. company name) for Prometheus remote write. Will be used as a Prometheus label and basic auth username. This will be stored in the Prometheus remote write basic auth Kubernetes secret."
  type        = string
}

variable "prom_remote_write_password" {
  description = "Prometheus remote write basic auth password. This will be stored in the Prometheus remote write basic auth Kubernetes secret."
  type        = string
  sensitive   = true
}
