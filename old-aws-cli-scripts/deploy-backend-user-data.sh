#!/bin/bash
set -e

echo "🔄 Updating system packages..."
yum update -y

echo "📦 Enabling Amazon Corretto 17..."
amazon-linux-extras enable corretto17

echo "📦 Installing Java 17, AWS CLI, and unzip..."
yum install -y java-17-amazon-corretto aws-cli unzip

echo "📁 Changing to EC2 user home directory..."
cd /home/ec2-user || exit

echo "⬇️ Downloading backend app zip from S3..."
aws s3 cp s3://aws-transactions-app-bucket/backend/app.zip .

echo "📂 Unzipping backend app..."
unzip app.zip

echo "🔒 Making JAR file executable..."
chmod +x *.jar

echo "🚀 Launching Spring Boot application..."
nohup java -jar *.jar > app.log 2>&1 &

echo "✅ Backend deployment script completed successfully."