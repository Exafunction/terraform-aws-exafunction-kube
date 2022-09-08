output "cluster_autoscaler_helm_release_metadata" {
  description = "Cluster autoscaler Helm release attributes."
  value       = module.eks_cluster_autoscaler.helm_release_metadata
}

output "nvidia_device_plugin_helm_release_metadata" {
  description = "NVIDIA device plugin Helm release attributes."
  value       = helm_release.nvidia_device_plugin.metadata
}

output "exadeploy_helm_release_metadata" {
  description = "ExaDeploy Helm release attributes."
  value       = helm_release.exadeploy.metadata
}

output "prometheus_helm_release_metadata" {
  description = "Prometheus Helm release attributes."
  value       = helm_release.kube_prometheus_stack.metadata
}
