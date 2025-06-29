#!/bin/bash
set -e

echo "🔄 Updating system packages..."
yum update -y

echo "📦 Enabling Nginx in Amazon Linux Extras..."
amazon-linux-extras enable nginx1

echo "📦 Installing Nginx and AWS CLI..."
yum install -y nginx aws-cli

echo "🚀 Enabling and starting Nginx..."
systemctl enable nginx
systemctl start nginx

echo "🧹 Removing default Nginx content..."
rm -rf /usr/share/nginx/html/*

echo "⬇️ Downloading React build from S3..."
aws s3 cp s3://aws-transactions-app-bucket/frontend/ /usr/share/nginx/html/ --recursive

echo "🔁 Restarting Nginx..."
systemctl restart nginx

echo "✅ Frontend deployment script completed successfully."