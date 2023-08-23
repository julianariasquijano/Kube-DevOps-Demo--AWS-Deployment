# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
# Changes made after the initial copyrighted code are not covered by the copyright. 

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}
output "cluster_arn" {
  description = "ARN assigned for the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "update_kubeconfig_command" {
  description = "Update kubeconfig command"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "set_kubectl_context_command" {
  description = "Set kubectl context command"
  value       = "kubectl config use-context ${module.eks.cluster_arn}"
}