# PostgreSQL RDS Instance
resource "aws_db_instance" "rds_instance" {
  identifier              = "aws-transactions-app-db-instance-id"
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                    = "AwsTransactionsAppDb"
  username                = "eduard_rds_user"
  # Best practice: move this to a secrets manager or use a variable
  password                = "eduard_rds_pass"

  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 0

  tags = {
    Name = "aws-transactions-app-db-instance"
  }
}