#!/bin/bash

# Update system packages
yum update -y

# Install Node.js 18.x
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Git and other utilities
yum install -y git wget curl

# Install PM2 for process management
npm install -g pm2

# Create application directory
mkdir -p /opt/socketio-app
cd /opt/socketio-app

# Create systemd service for the application
cat > /etc/systemd/system/socketio-app.service << 'EOF'
[Unit]
Description=Socket.IO Chat Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/socketio-app
ExecStart=/usr/bin/node index.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=${app_port}

# Logging
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=socketio-app

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /opt/socketio-app

# Enable the service (but don't start it yet - it will be started by the deployment)
systemctl daemon-reload
systemctl enable socketio-app

# Install CloudWatch agent (optional)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create log directory
mkdir -p /var/log/socketio-app
chown ec2-user:ec2-user /var/log/socketio-app

# Install nginx for reverse proxy (optional)
amazon-linux-extras install nginx1 -y

# Configure nginx as reverse proxy
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream socketio_backend {
        server 127.0.0.1:${app_port};
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://socketio_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Socket.IO specific configuration
        location /socket.io/ {
            proxy_pass http://socketio_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Create deployment script
cat > /opt/deploy.sh << 'EOF'
#!/bin/bash
set -e

APP_DIR="/opt/socketio-app"
BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting deployment at $(date)"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup current version if it exists
if [ -d "$APP_DIR" ] && [ "$(ls -A $APP_DIR)" ]; then
    echo "Creating backup of current version..."
    tar -czf "$BACKUP_DIR/socketio-app-$TIMESTAMP.tar.gz" -C "$APP_DIR" .
fi

# Stop the application if it's running
echo "Stopping application..."
systemctl stop socketio-app || true

# Clean the application directory
rm -rf $APP_DIR/*

echo "Deployment script ready. Application files should be copied to $APP_DIR"
echo "After copying files, run: systemctl start socketio-app"
EOF

chmod +x /opt/deploy.sh
chown ec2-user:ec2-user /opt/deploy.sh

echo "EC2 instance setup completed successfully!" > /var/log/user-data.log