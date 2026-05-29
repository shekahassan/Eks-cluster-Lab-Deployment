#!/bin/bash

################################################################################
# Automated Kubernetes Cluster Deployment Script
# Deploys a complete Kubernetes cluster with 1 master and 3 workers
# All workers automatically join the cluster
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP=${MASTER_IP:-""}
WORKER_IPS=()
SSH_USER="ubuntu"
SSH_KEY_PATH="${HOME}/.ssh/id_rsa"
KUBERNETES_VERSION="1.28"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

################################################################################
# Helper Functions
################################################################################

execute_remote_command() {
    local node_ip=$1
    local command=$2
    local description=${3:-"Executing command"}
    
    log_info "$description on $node_ip..."
    
    if [ -f "$SSH_KEY_PATH" ]; then
        ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$node_ip" \
            "bash -s" <<< "$command"
    else
        ssh -o StrictHostKeyChecking=no "$SSH_USER@$node_ip" \
            "bash -s" <<< "$command"
    fi
}

get_setup_script() {
    # Return the common setup script for all nodes
    cat << 'SETUP_SCRIPT'
#!/bin/bash

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y \
    curl wget git apt-transport-https ca-certificates \
    gnupg lsb-release net-tools htop

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl start docker
systemctl enable docker

# Configure Docker daemon
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker

# Configure kernel modules
modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl -p /etc/sysctl.d/kubernetes.conf > /dev/null

# Install kubeadm, kubelet, kubectl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
    https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
    https://apt.kubernetes.io/ kubernetes-xenial main" | \
    tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl start kubelet
systemctl enable kubelet

echo "Node setup completed successfully"
SETUP_SCRIPT
}

get_master_init_script() {
    local master_ip=$1
    
    cat << MASTER_SCRIPT
#!/bin/bash

# Initialize master node
kubeadm init \
    --apiserver-advertise-address=$master_ip \
    --pod-network-cidr=10.244.0.0/16 \
    --kubernetes-version=v${KUBERNETES_VERSION} \
    --ignore-preflight-errors=all

# Setup kubeconfig
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown \$(id -u):\$(id -g) /root/.kube/config

# Wait a moment for the API to be fully ready
sleep 10

# Install Flannel CNI
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Wait for Flannel pods to start
sleep 15

# Generate and save join command
kubeadm token create --print-join-command > /tmp/join_command.txt

echo "Master node initialized successfully"
MASTER_SCRIPT
}

get_worker_join_script() {
    local join_command=$1
    
    cat << WORKER_SCRIPT
#!/bin/bash

# Join cluster
$join_command --ignore-preflight-errors=all

echo "Worker node joined successfully"
WORKER_SCRIPT
}

################################################################################
# Setup Phase
################################################################################

display_usage() {
    cat << EOF

${GREEN}Kubernetes Cluster Deployment Script${NC}

This script automates the deployment of a Kubernetes cluster with:
  - 1 Master node
  - 3 Worker nodes (auto-joining)

${YELLOW}Usage:${NC}
  $0 <master_ip> <worker_ip1> <worker_ip2> <worker_ip3>

${YELLOW}Example:${NC}
  $0 192.168.1.10 192.168.1.11 192.168.1.12 192.168.1.13

${YELLOW}Configuration:${NC}
  SSH User: $SSH_USER
  SSH Key: $SSH_KEY_PATH
  Kubernetes Version: v$KUBERNETES_VERSION
  Pod Network CIDR: 10.244.0.0/16
  Network Plugin: Flannel

${YELLOW}Requirements:${NC}
  - SSH access to all nodes
  - Ubuntu 18.04+ on all nodes
  - sudo privileges on all nodes
  - Internet connectivity on all nodes

EOF
}

################################################################################
# Main Deployment
################################################################################

main() {
    log_section "Kubernetes Cluster Deployment"
    
    # Validate arguments
    if [ $# -lt 4 ]; then
        display_usage
        exit 1
    fi
    
    MASTER_IP=$1
    WORKER_IPS=($2 $3 $4)
    
    log_info "Master IP: $MASTER_IP"
    log_info "Worker IPs: ${WORKER_IPS[@]}"
    echo ""
    
    # Validate connectivity
    log_section "Validating Node Connectivity"
    
    for ip in $MASTER_IP "${WORKER_IPS[@]}"; do
        if ping -c 1 "$ip" &> /dev/null; then
            log_info "✓ $ip is reachable"
        else
            log_error "✗ $ip is not reachable"
            exit 1
        fi
    done
    
    # Setup all nodes
    log_section "Setting Up All Nodes"
    
    setup_script=$(get_setup_script)
    
    log_info "Setting up master node..."
    execute_remote_command "$MASTER_IP" "$setup_script" "Setting up master node"
    
    for i in "${!WORKER_IPS[@]}"; do
        log_info "Setting up worker node $((i+1))..."
        execute_remote_command "${WORKER_IPS[$i]}" "$setup_script" "Setting up worker node $((i+1))"
    done
    
    log_info "All nodes configured"
    
    # Initialize master
    log_section "Initializing Master Node"
    
    master_init_script=$(get_master_init_script "$MASTER_IP")
    execute_remote_command "$MASTER_IP" "$master_init_script" "Initializing master node"
    
    log_info "Master node initialized"
    
    # Get join command from master
    log_section "Retrieving Join Command"
    
    join_command=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
        "$SSH_USER@$MASTER_IP" "cat /tmp/join_command.txt" 2>/dev/null)
    
    if [ -z "$join_command" ]; then
        log_error "Failed to retrieve join command from master"
        exit 1
    fi
    
    log_info "Join command retrieved"
    
    # Join workers
    log_section "Joining Worker Nodes"
    
    for i in "${!WORKER_IPS[@]}"; do
        worker_ip="${WORKER_IPS[$i]}"
        log_info "Joining worker node $((i+1)) ($worker_ip)..."
        
        worker_script=$(get_worker_join_script "$join_command")
        execute_remote_command "$worker_ip" "$worker_script" "Joining worker node $((i+1))"
    done
    
    log_info "All worker nodes joined"
    
    # Verify cluster
    log_section "Verifying Cluster"
    
    verify_script='
    export KUBECONFIG=/etc/kubernetes/admin.conf
    sleep 10
    echo "=== Cluster Nodes ==="
    kubectl get nodes -o wide
    echo ""
    echo "=== Cluster Info ==="
    kubectl cluster-info
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -A
    '
    
    execute_remote_command "$MASTER_IP" "$verify_script" "Verifying cluster status"
    
    # Summary
    log_section "Deployment Complete!"
    
    cat << SUMMARY

${GREEN}Kubernetes Cluster Successfully Deployed!${NC}

${YELLOW}Master Node:${NC}
  IP Address: $MASTER_IP
  
${YELLOW}Worker Nodes:${NC}
EOF
    
    for i in "${!WORKER_IPS[@]}"; do
        echo "  Worker $((i+1)): ${WORKER_IPS[$i]}"
    done
    
    cat << SUMMARY

${YELLOW}Next Steps:${NC}
  1. SSH into master: ssh $SSH_USER@$MASTER_IP
  2. Check cluster status: kubectl get nodes
  3. View cluster info: kubectl cluster-info
  4. Deploy applications: kubectl apply -f <manifest.yaml>
  
${YELLOW}Access kubeconfig:${NC}
  Run on master: sudo cat /etc/kubernetes/admin.conf
  
${YELLOW}Useful Commands:${NC}
  - Get nodes: kubectl get nodes -o wide
  - Get pods: kubectl get pods -A
  - Describe node: kubectl describe node <node-name>
  - View logs: kubectl logs -f <pod-name> -n <namespace>

SUMMARY
    
}

# Run main function
main "$@"
