# Kube-DevOps-Demo--AWS-Deployment
Demostration of Kubernetes deployment on AWS EKS

After executing the actual terraform code, the architecture should be:

<img src="https://github.com/julianariasquijano/Kube-DevOps-Demo--AWS-Deployment/raw/main/images/Kube-DevOps-Demo--AWS-Deployment.png" width="35%">

Code initially based on the repository located in:
- https://github.com/hashicorp/learn-terraform-provision-eks-cluster

IAM Account required permissions:

- Create CloudWatch log groups
- Create KMS Keys


Using the outputs of the terraform apply command, update the the kubectl configuration with this command:
```
aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)
```

Then change to the new cluster context with:
```
kubectl config use-context <context_name>
```

Each availability zone configured for the VPC will have one private subnet and one public subnet

References:

- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks