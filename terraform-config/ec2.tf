# Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2 Key Pair (assumes you have a public key file)
resource "aws_key_pair" "ec2_key" {
  key_name   = "aws-transactions-app-ec2-key"
  public_key = file("${path.module}/aws-transactions-app-ec2-key.pub")
}

# Frontend EC2 instance
resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = aws_key_pair.ec2_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  depends_on = [aws_s3_object.frontend_files]
  user_data = file("${path.module}/deploy-frontend-user-data.sh")

  tags = {
    Name = "aws-transactions-app-frontend-ec2"
  }
}

# Backend EC2 instance
resource "aws_instance" "backend" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"

  /*
  TODO Important: Had to use the public subnet to be able to install node js, aws cli, unzip on
    the backend ec2 instance. This avoids costs for a NAT Gateway which would be
    the right approach but is not part of AWS Free Tier.
  */
  # subnet_id                   = aws_subnet.private_1.id
  subnet_id                   = aws_subnet.public.id

  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  key_name                    = aws_key_pair.ec2_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  depends_on = [aws_s3_object.backend_zip]
  user_data = file("${path.module}/deploy-backend-user-data.sh")

  tags = {
    Name = "aws-transactions-app-backend-ec2"
  }
}