#!/bin/bash

# Manual deployment script for Socket.IO app
# This script can be used for manual deployments when GitHub Actions is not available

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
APP_DIR="$SCRIPT_DIR/app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS CLI is installed and configured
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI is not installed. Make sure AWS credentials are configured."
    fi
    
    # Check if terraform.tfvars exists
    if [ ! -f "$INFRA_DIR/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found. Please create it from terraform.tfvars.example"
        exit 1
    fi
    
    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        print_warning "SSH public key not found at ~/.ssh/id_rsa.pub"
        print_warning "Make sure you have configured the correct SSH key in terraform.tfvars"
    fi
    
    print_success "Prerequisites check completed"
}

deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd "$INFRA_DIR"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    print_status "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    echo
    read -p "Do you want to apply this plan? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
    
    # Apply configuration
    print_status "Applying Terraform configuration..."
    terraform apply -auto-approve tfplan
    
    print_success "Infrastructure deployment completed"
}

get_instance_info() {
    print_status "Getting instance information..."
    
    cd "$INFRA_DIR"
    
    INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
    
    if [ -z "$INSTANCE_IP" ]; then
        print_error "Could not get instance IP. Make sure Terraform has been applied successfully."
        exit 1
    fi
    
    echo "Instance IP: $INSTANCE_IP"
    echo "Instance ID: $INSTANCE_ID"
    
    # Export for use in other functions
    export INSTANCE_IP
    export INSTANCE_ID
}

wait_for_instance() {
    print_status "Waiting for EC2 instance to be ready..."
    
    for i in {1..30}; do
        if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "echo 'Instance is ready'" &>/dev/null; then
            print_success "Instance is ready!"
            return 0
        fi
        print_status "Attempt $i/30: Instance not ready yet, waiting 30 seconds..."
        sleep 30
    done
    
    print_error "Instance is not responding after 15 minutes. Please check AWS console."
    exit 1
}

deploy_application() {
    print_status "Deploying application to EC2 instance..."
    
    cd "$APP_DIR"
    
    # Create deployment package
    print_status "Creating deployment package..."
    tar -czf ../socketio-app.tar.gz .
    
    cd "$SCRIPT_DIR"
    
    # Run deployment script on EC2
    print_status "Running deployment script on EC2..."
    ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "sudo /opt/deploy.sh"
    
    # Copy application files
    print_status "Copying application files..."
    scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no socketio-app.tar.gz ec2-user@$INSTANCE_IP:/tmp/
    
    # Setup application on EC2
    print_status "Setting up application on EC2..."
    ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'EOF'
        set -e
        
        # Extract application files
        cd /opt/socketio-app
        sudo tar -xzf /tmp/socketio-app.tar.gz
        
        # Install dependencies
        sudo npm install --production
        
        # Set proper ownership
        sudo chown -R ec2-user:ec2-user /opt/socketio-app
        
        # Update package.json start script for production
        sudo sed -i 's/"start": "nodemon index.js"/"start": "node index.js"/' package.json
        
        # Start the application
        sudo systemctl start socketio-app
        sudo systemctl enable socketio-app
        
        echo "Application deployed successfully!"
EOF
    
    # Clean up
    rm -f socketio-app.tar.gz
    
    print_success "Application deployment completed!"
}

show_deployment_info() {
    echo
    echo "=========================="
    echo "   DEPLOYMENT SUMMARY"
    echo "=========================="
    echo "🚀 Deployment completed successfully!"
    echo "📍 Instance IP: $INSTANCE_IP"
    echo "🌐 Application URL: http://$INSTANCE_IP:3000"
    echo "🔗 Nginx URL: http://$INSTANCE_IP"
    echo "🔑 SSH Command: ssh -i ~/.ssh/id_rsa ec2-user@$INSTANCE_IP"
    echo
    echo "Application logs: sudo journalctl -u socketio-app -f"
    echo "Nginx logs: sudo tail -f /var/log/nginx/access.log"
    echo "=========================="
}

destroy_infrastructure() {
    print_warning "This will destroy all AWS resources created by Terraform."
    read -p "Are you sure you want to destroy the infrastructure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Destroy cancelled by user"
        exit 0
    fi
    
    cd "$INFRA_DIR"
    terraform destroy -auto-approve
    print_success "Infrastructure destroyed successfully"
}

show_help() {
    echo "Socket.IO App Deployment Script"
    echo
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  deploy     Deploy infrastructure and application"
    echo "  app-only   Deploy only the application (infrastructure must exist)"
    echo "  destroy    Destroy all AWS infrastructure"
    echo "  status     Show current deployment status"
    echo "  help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 deploy          # Full deployment"
    echo "  $0 app-only        # Update application only"
    echo "  $0 destroy         # Clean up resources"
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        check_prerequisites
        deploy_infrastructure
        get_instance_info
        wait_for_instance
        deploy_application
        show_deployment_info
        ;;
    "app-only")
        check_prerequisites
        get_instance_info
        wait_for_instance
        deploy_application
        show_deployment_info
        ;;
    "destroy")
        destroy_infrastructure
        ;;
    "status")
        get_instance_info
        show_deployment_info
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac