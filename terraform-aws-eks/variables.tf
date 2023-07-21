# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
# Changes made after the initial copyrighted code are not covered by the copyright. 

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "resources-prefix" {
  description = "String used for tagging"
  type        = string
  default     = "eks-demo"
}