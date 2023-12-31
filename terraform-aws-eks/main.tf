# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
# Changes made after the initial copyrighted code are not covered by the copyright. 

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "${var.resources-prefix}-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}
/*
Elements to be created:
- VPC
- Private subnets
- Public subnets
- NAT Gateway
*/
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.resources-prefix}-vpc"

  cidr = "10.0.0.0/16"

  #Assings to azs the first three regions defined
  #Slice : startindex is inclusive, while endindex is exclusive
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  #single_nat_gateway across the all the private networks
  single_nat_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
    "solution"                                    = var.resources-prefix
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
    "solution"                                    = var.resources-prefix
  }
}
/*
Elements to be created:
- EKS Cluster
- EKS Managed node group
*/
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  #kubernetes version
  cluster_version = "1.27"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    iam_role_additional_policies = {
      AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
    }    

  }

  eks_managed_node_groups = {
    one = {
      name = "${var.resources-prefix}-node-group-1"

      instance_types = ["t2.small"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
      capacity_type  = "SPOT"
    }
    
    two = {
      name = "${var.resources-prefix}-node-group-2"

      instance_types = ["t2.small"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
    
  }
}

/*
Elements to be created:
- Single IAM role which can be assumed by trusted resources using OpenID Connect Federated Users.
# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "${var.resources-prefix}-AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
*/
/*
Elements to be created:
- EKS ADDON to let the clusters manage the lifecycle of Amazon EBS volumes for persistent volumes
*/
/*
resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.20.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
    "solution"  = var.resources-prefix
  }
}
*/
module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.resources-prefix}_eks_lb_role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
resource "null_resource" "iamserviceaccount" {
  provisioner "local-exec" {
    command = "eksctl create iamserviceaccount --name aws-load-balancer-controller --namespace kube-system --cluster ${module.eks.cluster_name}  --attach-role-arn ${module.lb_role.iam_role_arn} --approve --override-existing-serviceaccounts"
  }

}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "ingress" {
  name       = "ingress"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.4.6"

  set {
    name  = "autoDiscoverAwsRegion"
    value = "true"
  }
  set {
    name  = "autoDiscoverAwsVpcID"
    value = "true"
  }
  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  depends_on = [module.lb_role]

}

resource "null_resource" "console_config" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} && kubectl config use-context ${module.eks.cluster_arn}"
  }

  depends_on = [helm_release.ingress]

}

resource "null_resource" "create_hello_world_service" {
  provisioner "local-exec" {
    command = "cd .. && cd kubernetes-yaml && kubectl apply -f eks-ingress-hello.yaml && sleep 10 && kubectl get ingress"
  }

  depends_on = [null_resource.console_config]

}