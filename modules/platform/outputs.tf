output "namespaces" {
  description = "Application namespaces"
  value       = [for ns in kubernetes_namespace_v1.app : ns.metadata[0].name]
}

output "gateway_class_name" {
  description = "GatewayClass for gateway.className in the Helm chart"
  value       = kubectl_manifest.gateway_class.name
}
