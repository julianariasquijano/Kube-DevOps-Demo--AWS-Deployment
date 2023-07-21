# Kube-DevOps-Demo--AWS-Deployment
Demostration of Kubernetes deployment on AWS

Code initially based on the tutorial located in:
- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
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