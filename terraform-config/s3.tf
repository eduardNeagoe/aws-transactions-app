# Create the S3 bucket
resource "aws_s3_bucket" "aws-transactions_app_bucket" {
  bucket = "aws-transactions-app-bucket"
  force_destroy = true  # Deletes even if bucket is not empty
}

# resource "null_resource" "upload_frontend_to_s3" {
#   provisioner "local-exec" {
#     command = "aws s3 cp ../frontend/build/ s3://aws-transactions-app-bucket/frontend/ --recursive"
#   }
#
#   triggers = {
#     always_run = "${timestamp()}"
#   }
# }

locals {
  frontend_files = fileset("${path.module}/../application-code/web-tier/build", "**")
}

# Copy app files to the bucket

resource "aws_s3_object" "frontend_files" {
  for_each = toset(local.frontend_files)

  bucket = "aws-transactions-app-bucket"
  key    = "frontend/${each.value}"
  source = "${path.module}/../application-code/web-tier/build/${each.value}"
  etag   = filemd5("${path.module}/../application-code/web-tier/build/${each.value}")
}

resource "aws_s3_object" "backend_zip" {
  bucket = "aws-transactions-app-bucket"
  key    = "backend/app.zip"
  source = "${path.module}/../application-code/app-tier/app.zip"
  etag   = filemd5("${path.module}/../application-code/app-tier/app.zip")
}
