#!/bin/bash

################################################################################
# Kubernetes Deployment Script using kubeadm
# This script deploys Kubernetes with 1 master and 3 worker nodes
# Workers automatically join the cluster
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KUBERNETES_VERSION="1.28"
MASTER_NODE=""
WORKER_NODES=()
CLUSTER_NAME="k8s-cluster"

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

################################################################################
# Prerequisites Installation
################################################################################

install_dependencies() {
    local node_name=$1
    
    log_info "Installing dependencies on $node_name..."
    
    # Update system packages
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    apt-get install -y \
        curl \
        wget \
        git \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        net-tools \
        htop
    
    log_info "Dependencies installed on $node_name"
}

################################################################################
# Install Docker Container Runtime
################################################################################

install_docker() {
    local node_name=$1
    
    log_info "Installing Docker on $node_name..."
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Configure Docker daemon
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
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
    
    log_info "Docker installed on $node_name"
}

################################################################################
# Disable Swap
################################################################################

disable_swap() {
    local node_name=$1
    
    log_info "Disabling swap on $node_name..."
    
    swapoff -a
    
    # Permanently disable swap
    sed -i '/ swap / s/^/#/' /etc/fstab
    
    log_info "Swap disabled on $node_name"
}

################################################################################
# Configure Kernel Modules and Network
################################################################################

configure_kernel() {
    local node_name=$1
    
    log_info "Configuring kernel modules on $node_name..."
    
    # Load required kernel modules
    modprobe overlay
    modprobe br_netfilter
    
    # Configure sysctl
    cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    
    sysctl -p /etc/sysctl.d/kubernetes.conf > /dev/null
    
    log_info "Kernel configured on $node_name"
}

################################################################################
# Install kubeadm, kubelet, and kubectl
################################################################################

install_kubernetes_tools() {
    local node_name=$1
    
    log_info "Installing Kubernetes tools on $node_name..."
    
    # Add Kubernetes GPG key
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    
    # Add Kubernetes repository
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
        tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
    
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    
    # Hold Kubernetes packages at current version
    apt-mark hold kubelet kubeadm kubectl
    
    # Start and enable kubelet
    systemctl start kubelet
    systemctl enable kubelet
    
    log_info "Kubernetes tools installed on $node_name"
}

################################################################################
# Initialize Master Node
################################################################################

init_master_node() {
    local master_ip=$1
    
    log_info "Initializing master node at $master_ip..."
    
    # Initialize kubeadm
    kubeadm init \
        --apiserver-advertise-address=$master_ip \
        --pod-network-cidr=10.244.0.0/16 \
        --kubernetes-version=v${KUBERNETES_VERSION} \
        --ignore-preflight-errors=all
    
    log_info "Master node initialized"
    
    # Setup kubeconfig for root user
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    chown $(id -u):$(id -g) /root/.kube/config
    
    log_info "kubeconfig setup complete"
}

################################################################################
# Install Network Plugin (Flannel CNI)
################################################################################

install_network_plugin() {
    log_info "Installing Flannel network plugin..."
    
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    
    log_info "Flannel network plugin installed"
    
    # Wait for Flannel pods to be ready
    log_info "Waiting for Flannel pods to be ready..."
    sleep 20
}

################################################################################
# Generate and Display Join Command
################################################################################

get_join_command() {
    log_info "Generating cluster join command..."
    
    local join_command=$(kubeadm token create --print-join-command)
    
    echo "$join_command"
}

################################################################################
# Join Worker Node to Cluster
################################################################################

join_worker_node() {
    local worker_name=$1
    local join_command=$2
    
    log_info "Joining worker node $worker_name to cluster..."
    
    eval $join_command --ignore-preflight-errors=all
    
    log_info "Worker node $worker_name joined successfully"
}

################################################################################
# Main Deployment Function
################################################################################

main() {
    echo ""
    echo "=========================================="
    echo "Kubernetes Deployment with kubeadm"
    echo "=========================================="
    echo ""
    
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        log_error "Usage: $0 [master|worker] [node_ip]"
        echo ""
        echo "Examples:"
        echo "  Setup Master node:  $0 master 192.168.1.10"
        echo "  Setup Worker node:  $0 worker 192.168.1.11"
        echo ""
        exit 1
    fi
    
    local role=$1
    local node_ip=$2
    
    if [ -z "$node_ip" ]; then
        log_error "Node IP address is required"
        exit 1
    fi
    
    # Verify user is root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    log_info "Starting Kubernetes setup on $role node ($node_ip)"
    echo ""
    
    # Common setup for all nodes
    log_info "Performing common setup steps..."
    install_dependencies "$role"
    install_docker "$role"
    disable_swap "$role"
    configure_kernel "$role"
    install_kubernetes_tools "$role"
    
    echo ""
    
    # Role-specific setup
    if [ "$role" == "master" ]; then
        init_master_node $node_ip
        echo ""
        install_network_plugin
        echo ""
        log_info "Master node setup complete!"
        echo ""
        log_info "To join worker nodes, use the following command on each worker:"
        echo ""
        join_cmd=$(get_join_command)
        echo "sudo $0 worker $node_ip_of_worker --join-command \"$join_cmd\""
        echo ""
        
    elif [ "$role" == "worker" ]; then
        # Check if join command is provided
        if [ $# -lt 3 ]; then
            log_warn "No join command provided. Please get it from master node."
            log_warn "Run on master node: kubeadm token create --print-join-command"
            log_warn "Then paste the output after running this script with --join-command flag"
            exit 1
        fi
        
        local join_command=$3
        join_worker_node "worker" "$join_command"
        
        log_info "Worker node setup complete!"
        
    else
        log_error "Invalid role: $role. Use 'master' or 'worker'"
        exit 1
    fi
    
    echo ""
    log_info "Setup completed successfully!"
    echo ""
}

# Run main function
main "$@"
