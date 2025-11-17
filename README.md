# Elasticsearch Deployment on Kubernetes using ECK Operator

This project deploys a single-node Elasticsearch cluster using the Elastic Cloud on Kubernetes (ECK) operator, on a kubeadm-based Kubernetes cluster running inside a Google Cloud VM.

## Prerequisites

Before deploying this project, make sure you have the following set up:

1. Terraform
You need to have Terraform installed on your local machine.  
Follow this guide to install:  
https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

Create terraform.tfvars file (this file is gitignored):

```bash
project = "Your GCP project id"
user = "User to ssh to GCP VM"
```
Update `backend.tf` with your bucket name

2. Create a GCP project. Enable **Cloud Resource Manager API**. Create **GCS bucket** to store Terraform state (enable versioning). Create **Service Account** with at least `Compute Admin` and `Storage Admin` roles. You can also use **default Compute Engine service account**.
Download service account JSON key and save it as `service.json` (this file is gitignored).

## Run following commands:

```bash
terraform init
terraform plan
terraform apply
```

This will create GCP VM with kubeadm cluster, install ECK operator and deploys Elasticsearch on it.


## How to check

```bash
ssh USER@IP # Terraform will print public IP of VM, ssh as user you provided in terraform.tfvars file
kubectl get pods # wait until you see pod is fully running
kubectl get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 --decode; echo # get elastic user password
```

From your local machine run:
```bash
curl -k -u "elastic:PASSWORD" https://IP:30092
```

To destroy:
```bash
terraform destroy
```

## You can also use GitHub Actions workflow to create everything.

You need to upload your service account as a secret with variable name `SERVICE_ACCOUNT`
Then select workflow and `Run workflow`, provide project id, bucket name and user and run `apply`
