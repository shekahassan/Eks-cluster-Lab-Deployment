# EKS Cluster Deployment Module

This Terraform module provisions a complete EKS cluster in AWS with all necessary networking and security components.

## Features

- **EKS Cluster** with Kubernetes version 1.34
- **VPC** with public and private subnets across 2 availability zones
- **NAT Gateways** for private subnet internet access
- **Security Groups** for cluster and node security
- **EKS Node Group** with configurable scaling
- **IAM Roles and Policies** for cluster and node operations

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured with credentials
- `kubectl` installed for cluster access

## Quick Start

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review Variables (Optional)

The default configuration includes:
- **Cluster Name**: sheka-dev
- **Region**: ca-central-1
- **Kubernetes Version**: 1.34
- **Node Configuration**: 2 desired, 1 minimum, 4 maximum nodes
- **Instance Type**: t3.medium

To customize, create a `terraform.tfvars` file:

```hcl
aws_region       = "ca-central-1"
cluster_name     = "sheka-dev"
kubernetes_version = "1.34"
desired_size     = 2
instance_types   = ["t3.medium"]
```

### 3. Plan the Deployment

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

### 5. Configure kubectl

After the cluster is created, configure your local kubeconfig:

```bash
aws eks update-kubeconfig --region ca-central-1 --name sheka-dev
```

Or use the output from Terraform:

```bash
terraform output kubeconfig_command
```

## Outputs

- `cluster_id` - The EKS cluster ID
- `cluster_endpoint` - The Kubernetes API endpoint
- `cluster_certificate_authority_data` - CA certificate for cluster authentication
- `node_group_id` - The node group ID
- `vpc_id` - The VPC ID
- `private_subnet_ids` - Private subnet IDs for node placement
- `public_subnet_ids` - Public subnet IDs for load balancers
- `kubeconfig_command` - Command to configure kubectl

## Module Structure

```
01-eks-cluster/
├── main.tf                      # Main infrastructure definitions
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── backend.tf                   # Backend configuration (optional)
├── terraform.tfvars.example     # Example variable values
└── README.md                    # This file
```

## Networking

- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (for load balancers)
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24 (for worker nodes)

## Security

- EKS Control Plane endpoint is publicly accessible for kubectl commands
- Worker nodes are placed in private subnets with NAT Gateway access
- Security groups restrict traffic between cluster and nodes

## Scaling

To modify the node group size, update the variables:

```bash
terraform apply -var="desired_size=3" -var="max_size=5"
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

### Check Cluster Status

```bash
aws eks describe-cluster --name sheka-dev --region ca-central-1
```

### View Node Group Status

```bash
aws eks describe-nodegroup --cluster-name sheka-dev --nodegroup-name sheka-dev-node-group --region ca-central-1
```

### Verify Nodes are Ready

```bash
kubectl get nodes
```

## Costs

- EKS Cluster: ~$0.10/hour
- NAT Gateway: ~$0.32/hour (per NAT Gateway)
- EC2 Instances: Based on instance type (t3.medium ~$0.0416/hour)

Total estimated cost: ~$50-100/month for the default configuration

## License

This module is provided as-is for deployment purposes.
