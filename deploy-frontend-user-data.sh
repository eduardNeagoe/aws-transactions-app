#!/bin/bash
# Update all packages
yum update -y

# Install Nginx and AWS CLI to serve static content and pull from S3
yum install -y nginx aws-cli

# Enable Nginx to start on boot and start it now
systemctl enable nginx
systemctl start nginx

# Clear default Nginx HTML content
rm -rf /usr/share/nginx/html/*

# Copy React build from S3 to Nginx HTML directory
aws s3 cp s3://aws-transactions-app-bucket/frontend/ /usr/share/nginx/html/ --recursive

# Restart Nginx to serve the new frontend
systemctl restart nginx
