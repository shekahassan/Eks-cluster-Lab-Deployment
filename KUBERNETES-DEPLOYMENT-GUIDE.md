# Kubernetes Deployment Guide (kubeadm)

This guide provides bash scripts to deploy a Kubernetes cluster with 1 master node and 3 worker nodes that automatically join the cluster.

## Overview

Two deployment scripts are provided:

1. **`deploy-kubernetes-kubeadm.sh`** - Manual deployment script for individual nodes
2. **`auto-deploy-kubernetes.sh`** - Automated script for complete cluster deployment

## Architecture

```
┌─────────────────────────────────────┐
│      Master Node (Control Plane)    │
│  - API Server                       │
│  - Controller Manager               │
│  - Scheduler                        │
│  - etcd                             │
└──────┬──────────────────────────────┘
       │
       ├─────────────────────┬─────────────────────┬─────────────────────┐
       │                     │                     │                     │
   ┌───┴────┐           ┌───┴────┐           ┌───┴────┐           ┌───┴────┐
   │ Worker │           │ Worker │           │ Worker │           │ Worker │
   │  Node  │           │  Node  │           │  Node  │           │  Node  │
   │   #1   │           │   #2   │           │   #3   │           │ (Optional)
   └────────┘           └────────┘           └────────┘           └────────┘

Network: 10.244.0.0/16 (Flannel CNI)
```

## Prerequisites

### System Requirements
- Ubuntu 18.04 LTS or higher on all nodes
- 2+ CPU cores per node (4+ recommended for master)
- 2GB+ RAM per node (4GB+ recommended for master)
- 20GB+ disk space per node
- Internet connectivity on all nodes

### Network Requirements
- All nodes must be on the same network
- Ports must be open:
  - Master: 6443 (API), 2379-2380 (etcd), 10250-10259, 10257, 10259
  - Workers: 10250, 30000-32767

### SSH Requirements (for auto deployment)
- SSH access from deployment machine to all nodes
- sudo privileges (passwordless preferred)
- SSH key pair configured (optional if password auth is set up)

---

## Method 1: Manual Deployment (deploy-kubernetes-kubeadm.sh)

Use this method when you want to set up nodes individually or need more control.

### Step 1: Prepare the Scripts

```bash
# Download or copy the script to your master node
scp deploy-kubernetes-kubeadm.sh ubuntu@<master-ip>:~/

# SSH into master node
ssh ubuntu@<master-ip>
```

### Step 2: Setup Master Node

```bash
# Copy script to master
sudo cp deploy-kubernetes-kubeadm.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/deploy-kubernetes-kubeadm.sh

# Run setup on master node
sudo deploy-kubernetes-kubeadm.sh master <master-ip>

# Example
sudo deploy-kubernetes-kubeadm.sh master 192.168.1.10
```

Wait for the script to complete (takes 5-10 minutes).

### Step 3: Get Join Token from Master

After master setup completes, get the join command:

```bash
# On master node, run:
kubeadm token create --print-join-command
```

This will output something like:
```
kubeadm join 192.168.1.10:6443 --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:abcdef1234567890...
```

### Step 4: Setup Worker Nodes

For each worker node:

```bash
# Copy script to worker
scp deploy-kubernetes-kubeadm.sh ubuntu@<worker-ip>:~/
ssh ubuntu@<worker-ip>

# Run setup on worker node
sudo cp deploy-kubernetes-kubeadm.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/deploy-kubernetes-kubeadm.sh

# Setup as worker (without join yet)
sudo deploy-kubernetes-kubeadm.sh worker <worker-ip>
```

This installs all prerequisites and Kubernetes tools but won't join yet.

### Step 5: Join Workers Automatically

You have two options:

**Option A: Use the wrapper command in the script**
```bash
# On each worker node, use the saved join command
sudo kubeadm join 192.168.1.10:6443 --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:abcdef1234567890...
```

**Option B: Use the script's join functionality**
```bash
# The manual setup requires you to run the join command separately
sudo kubeadm join 192.168.1.10:6443 --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:abcdef1234567890...
```

### Step 6: Verify Cluster

```bash
# SSH back to master node
ssh ubuntu@<master-ip>

# Check nodes
kubectl get nodes

# Expected output (after 1-2 minutes):
# NAME      STATUS   ROLES           AGE   VERSION
# master    Ready    control-plane   5m    v1.28.x
# worker1   Ready    <none>          2m    v1.28.x
# worker2   Ready    <none>          2m    v1.28.x
# worker3   Ready    <none>          2m    v1.28.x

# Check all pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

---

## Method 2: Automated Deployment (auto-deploy-kubernetes.sh)

Use this method for a fully automated cluster deployment from a single command.

### Prerequisites for Automated Deployment

Before running the automated script, ensure:

1. **SSH Access** - You can SSH to all nodes without entering passwords:
   ```bash
   # Generate SSH key if you don't have one
   ssh-keygen -t rsa -b 4096

   # Copy public key to all nodes
   ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@<node-ip>
   ```

2. **Master Node IP** and **3 Worker Node IPs** ready

3. **Edit the script** (optional) to set SSH_USER if different:
   ```bash
   SSH_USER="your-username"  # Default: ubuntu
   SSH_KEY_PATH="${HOME}/.ssh/id_rsa"  # Path to SSH key
   ```

### Step 1: Prepare the Script

```bash
# Copy script to your local/deployment machine
# Make it executable
chmod +x auto-deploy-kubernetes.sh

# Verify permissions
./auto-deploy-kubernetes.sh
# This will show usage information
```

### Step 2: Run Automated Deployment

```bash
# Basic usage
./auto-deploy-kubernetes.sh <master-ip> <worker1-ip> <worker2-ip> <worker3-ip>

# Example
./auto-deploy-kubernetes.sh 192.168.1.10 192.168.1.11 192.168.1.12 192.168.1.13
```

The script will:
1. ✓ Validate connectivity to all nodes
2. ✓ Install Docker on all nodes
3. ✓ Install kubeadm, kubelet, kubectl on all nodes
4. ✓ Configure kernel modules and network settings
5. ✓ Initialize the master node
6. ✓ Install Flannel CNI (networking)
7. ✓ Generate join tokens
8. ✓ Automatically join all worker nodes
9. ✓ Verify the cluster

**Time required:** ~15-20 minutes depending on network speed

### Step 3: Verify Cluster Status

Once the script completes, all nodes are ready. SSH to master and check:

```bash
ssh ubuntu@<master-ip>

# Check nodes
kubectl get nodes -o wide

# Expected output:
# NAME      STATUS   ROLES           AGE   VERSION   INTERNAL-IP
# master    Ready    control-plane   3m    v1.28.x   192.168.1.10
# worker1   Ready    <none>          2m    v1.28.x   192.168.1.11
# worker2   Ready    <none>          2m    v1.28.x   192.168.1.12
# worker3   Ready    <none>          2m    v1.28.x   192.168.1.13
```

---

## Post-Deployment Steps

### 1. Copy kubeconfig

Access the cluster from your local machine:

```bash
# SSH to master and copy kubeconfig
ssh ubuntu@<master-ip> "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config

# Verify
kubectl get nodes
```

### 2. Install Additional Addons (Optional)

```bash
# Metrics Server (for resource monitoring)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Access dashboard
kubectl proxy
# Then visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### 3. Create Sample Deployment

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose the service
kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort

# Check status
kubectl get pods
kubectl get svc
```

---

## Troubleshooting

### Issue: Nodes in NotReady state

```bash
# Check node details
kubectl describe node <node-name>

# Check kubelet logs on that node
ssh ubuntu@<node-ip>
sudo journalctl -u kubelet -f
```

### Issue: Pods are pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check networking
kubectl get pods -n kube-flannel
```

### Issue: Cannot access cluster from remote machine

```bash
# Copy kubeconfig from master to your machine
scp ubuntu@<master-ip>:/etc/kubernetes/admin.conf ~/.kube/config

# Update the server address if needed (change IP to master IP)
# Edit ~/.kube/config and update:
# server: https://<master-ip>:6443
```

### Issue: Worker node stuck in NotReady

```bash
# On the worker node:
# 1. Check Docker is running
docker ps

# 2. Check kubelet is running
sudo systemctl status kubelet

# 3. Reset and rejoin if needed
sudo kubeadm reset -f
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### Reset and Start Over

If you need to reset and start fresh:

```bash
# On each node (master and workers)
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo systemctl stop docker
sudo docker system prune -a --volumes -f

# Then re-run setup scripts
```

---

## Security Considerations

1. **SSH Keys**: Use SSH keys instead of passwords
2. **Network Policies**: Implement Kubernetes network policies
3. **RBAC**: Configure role-based access control
4. **Updates**: Regularly patch all nodes
5. **Firewall**: Restrict access to Kubernetes API (port 6443)

---

## Performance Tuning

### Master Node
```bash
# Increase API server resources
# Edit /etc/kubernetes/manifests/kube-apiserver.yaml
# Add:
# - --max-requests=3000
# - --max-requests-inflight=1500
```

### Worker Nodes
```bash
# Increase kubelet resources
# Edit /etc/default/kubelet
# Add: KUBELET_EXTRA_ARGS="--max-pods=250"
```

---

## Useful Commands

```bash
# Cluster information
kubectl cluster-info
kubectl version
kubectl get nodes -o wide

# Pod management
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Deployment management
kubectl get deployments -A
kubectl scale deployment <name> --replicas=5 -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>

# Service management
kubectl get svc -A
kubectl port-forward svc/<service> 8080:80 -n <namespace>

# Debugging
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
kubectl port-forward <pod-name> 8080:8080 -n <namespace>
```

---

## Script Details

### deploy-kubernetes-kubeadm.sh
- Manual setup for individual nodes
- Can be used on master or worker nodes
- Idempotent (safe to run multiple times)
- Detailed logging with colored output

### auto-deploy-kubernetes.sh
- Fully automated cluster deployment
- Uses SSH to remote into nodes
- Deploys all components in correct order
- Automatic worker node joining

---

## References

- [Official kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Flannel Networking](https://github.com/coreos/flannel)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

## Support & Issues

For issues or questions:
1. Check the [Kubernetes Official Documentation](https://kubernetes.io/docs/)
2. Review logs: `journalctl -u kubelet -f` on nodes
3. Check cluster events: `kubectl get events -A`
4. Common issues are usually related to networking or firewall rules

---

**Last Updated:** January 2026
**Tested On:** Ubuntu 20.04 LTS / Ubuntu 22.04 LTS
**Kubernetes Version:** v1.28+
