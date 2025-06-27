#!/bin/bash
# Update all packages
yum update -y

# Enable Amazon Corretto 17 (Java 17)
amazon-linux-extras enable corretto17

# Install Java 17, AWS CLI, and unzip utility
yum install -y java-17-amazon-corretto aws-cli unzip

# Move to ec2-user's home directory
cd /home/ec2-user || exit

# Download the backend app zip file from S3
aws s3 cp s3://aws-transactions-app-bucket/backend/app.zip .

# Unzip the backend app
unzip app.zip

# Make the .jar file executable (precaution)
chmod +x *.jar

# Run the Spring Boot app in the background and log output
nohup java -jar *.jar > app.log 2>&1 &
