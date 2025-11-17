# Elasticsearch Deployment on Kubernetes using ECK Operator

This project deploys a single-node Elasticsearch cluster using the Elastic Cloud on Kubernetes (ECK) operator, on a kubeadm-based Kubernetes cluster running inside a Google Cloud VM.

## Prerequisites

Before deploying this project, make sure you have the following set up:

1. Terraform
You need to have Terraform installed on your local machine.  
Follow this guide to install:  
https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

2. Create a GCP project. Enable **Cloud Resource Manager API**. Create **GCS bucket** to store Terraform state (enable versioning). Create **Service Account** with at least `Compute Admin` and `Storage Admin` roles. You can also use **default Compute Engine service account**.
