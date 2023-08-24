# Kube-DevOps-Demo--AWS-Deployment
Demostration of Kubernetes deployment on AWS EKS

After executing the actual terraform code, the architecture should be:

<img src="https://github.com/julianariasquijano/Kube-DevOps-Demo--AWS-Deployment/raw/main/images/Kube-DevOps-Demo--AWS-Deployment.png" width="100%">

Code initially based on the repository located in:
- https://github.com/hashicorp/learn-terraform-provision-eks-cluster

IAM Account required permissions:

- Create CloudWatch log groups
- Create KMS Keys
- For getting a public address for the Ingress service, Administrator ACCESS policy (should be removed after creating the cluster)


The terraform script will run the aws eks update-kubeconfig  and the kubectl config use-context commands automatically. But if required, you can run the commands manually:

Update the the kubectl configuration with this command:
```
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

Then change to the new cluster context with:
```
kubectl config use-context <context_name>
```

Each availability zone configured for the VPC will have one private subnet and one public subnet

While destroying, manually you will have to delete:

- The load balancer created for the Ingress
- Some VPC security groups


References:

- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
