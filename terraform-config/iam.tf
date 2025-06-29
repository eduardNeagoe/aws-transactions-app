# # Create an IAM group called 'eduards-group'
# resource "aws_iam_group" "eduards_group" {
#   name = "eduards-group"
# }
#
# # # Create an IAM user named 'eduard'
# resource "aws_iam_user" "eduard_dev" {
#   name = "eduard_dev"
# }
#
# # Add the user 'eduard' to the 'eduards-group'
# resource "aws_iam_user_group_membership" "eduard_membership" {
#   user = aws_iam_user.eduard_dev.name
#
#   groups = [
#     aws_iam_group.eduards_group.name
#   ]
# }
#
# # Attach AmazonEC2FullAccess
# resource "aws_iam_group_policy_attachment" "ec2_full" {
#   group      = aws_iam_group.eduards_group.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
# }
#
# # Attach AmazonS3FullAccess
# resource "aws_iam_group_policy_attachment" "s3_full" {
#   group      = aws_iam_group.eduards_group.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
# }
#
# # Attach AmazonVPCFullAccess
# resource "aws_iam_group_policy_attachment" "vpc_full" {
#   group      = aws_iam_group.eduards_group.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
# }
#
# # Attach AmazonRDSFullAccess
# resource "aws_iam_group_policy_attachment" "rds_full" {
#   group      = aws_iam_group.eduards_group.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
# }

resource "aws_iam_role" "ec2_role" {
  name = "aws-transactions-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "rds_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "aws-transactions-app-ec2-profile"
  role = aws_iam_role.ec2_role.name
}