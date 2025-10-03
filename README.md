# Socket.IO Chat App - AWS EC2 Deployment

This project contains a simple Socket.IO chat application with infrastructure as code (Terraform) and automated deployment via GitHub Actions.

## 🏗️ Architecture

- **Application**: Node.js with Socket.IO and Express
- **Infrastructure**: AWS EC2 with Elastic IP, Security Groups, and IAM roles
- **Reverse Proxy**: Nginx for production-ready serving
- **Deployment**: GitHub Actions with manual workflow trigger
- **Infrastructure**: Terraform for reproducible AWS resource management

## 📋 Prerequisites

Before deploying, you'll need:

1. **AWS Account** with appropriate permissions
2. **SSH Key Pair** for EC2 access
3. **GitHub Repository** with this code
4. **Terraform** installed locally (for local testing)

## 🚀 Quick Start

### 1. Set up AWS Credentials

Create an IAM user with the following permissions:
- EC2 Full Access
- VPC Full Access
- IAM permissions for creating roles and policies

### 2. Configure SSH Keys

Generate an SSH key pair:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/socketio-app-key
```

### 3. Set GitHub Secrets

In your GitHub repository, go to Settings > Secrets and Variables > Actions, and add:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `EC2_PUBLIC_KEY` | Public SSH key content | `ssh-rsa AAAAB3NzaC1yc2EAAAA...` |
| `EC2_PRIVATE_KEY` | Private SSH key content | `-----BEGIN RSA PRIVATE KEY-----\n...` |

### 4. Deploy

1. Go to your GitHub repository
2. Navigate to **Actions** tab
3. Select **Deploy Socket.IO App to EC2** workflow
4. Click **Run workflow**
5. Choose your options:
   - Environment: `prod` or `staging`
   - Terraform action: `plan`, `apply`, or `destroy`
6. Click **Run workflow**

## 🛠️ Local Development

### Running the App Locally

```bash
cd app
npm install
npm start
```

The app will be available at http://localhost:3000

### Testing Infrastructure Locally

1. Copy the example terraform variables:
   ```bash
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   ```hcl
   aws_region = "us-east-1"
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA... your-public-key"
   ```

3. Initialize and plan:
   ```bash
   terraform init
   terraform plan
   ```

4. Apply (when ready):
   ```bash
   terraform apply
   ```

## 📁 Project Structure

```
socketsTest/
├── app/                          # Socket.IO application
│   ├── index.html               # Chat interface
│   ├── index.js                 # Express + Socket.IO server
│   └── package.json             # Node.js dependencies
├── infra/                        # Terraform infrastructure
│   ├── main.tf                  # Main infrastructure configuration
│   ├── variables.tf             # Terraform variables
│   ├── outputs.tf               # Terraform outputs
│   ├── user-data.sh             # EC2 initialization script
│   └── terraform.tfvars.example # Example configuration
├── .github/workflows/            # GitHub Actions
│   └── deploy.yml               # Deployment workflow
└── README.md                     # This file
```

## 🔧 Infrastructure Details

### AWS Resources Created

- **EC2 Instance**: Amazon Linux 2 with Node.js 18
- **Security Group**: Allows HTTP (80), HTTPS (443), Socket.IO (3000), and SSH (22)
- **Elastic IP**: Static public IP address
- **IAM Role**: EC2 service role with CloudWatch and SSM permissions
- **Key Pair**: SSH access to the instance

### Security Considerations

- SSH access is currently open to `0.0.0.0/0` - consider restricting to your IP
- Update the security group rules in `main.tf` to limit access as needed
- Use AWS Systems Manager Session Manager for more secure access
- Consider using Application Load Balancer for production deployments

### Cost Optimization

- Uses `t3.micro` instance (Free Tier eligible)
- EBS volume is encrypted for security
- Consider using reserved instances for long-term deployments

## 🔍 Monitoring and Troubleshooting

### Checking Application Status

SSH into the instance:
```bash
ssh -i ~/.ssh/socketio-app-key ec2-user@YOUR_INSTANCE_IP
```

Check application status:
```bash
sudo systemctl status socketio-app
sudo journalctl -u socketio-app -f
```

Check nginx status:
```bash
sudo systemctl status nginx
```

### Log Locations

- Application logs: `sudo journalctl -u socketio-app`
- Nginx logs: `/var/log/nginx/`
- System logs: `/var/log/messages`

### Common Issues

1. **Instance not responding**: Check security group rules
2. **Application not starting**: Check Node.js version and dependencies
3. **502 Bad Gateway**: Check if the application is running on port 3000

## 🔄 Updating the Application

The GitHub Actions workflow automatically:
1. Stops the current application
2. Backs up the existing version
3. Deploys the new version from the main branch
4. Restarts the application

## 🗑️ Cleanup

To destroy all AWS resources:
1. Go to GitHub Actions
2. Run the deploy workflow with `destroy` action
3. Alternatively, run locally: `terraform destroy`

## 📝 Customization

### Changing the Application Port

1. Update `var.app_port` in `infra/variables.tf`
2. Update the port in `app/index.js`
3. Redeploy using GitHub Actions

### Adding SSL/HTTPS

Consider adding:
- AWS Certificate Manager (ACM) certificate
- Application Load Balancer (ALB)
- Route 53 for DNS management

### Scaling

For production workloads, consider:
- Auto Scaling Groups
- Application Load Balancer
- RDS for persistent data storage
- ElastiCache for session management

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).