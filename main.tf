#Setting up the custom VPC with the specified cidr block variable and creating 2 subnet within the VPC in 2 availability zones.

resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = "backend-vpc"
  }
}

#Creating a public subnet where the ALB will resides
resource "aws_subnet" "pub-subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.pub_subnet_cidr_block
  availability_zone = "${var.region}a"

  tags = {
    Name = "backend-public-subnet1"
  }
}

#Creating a private subnet where the ECSs will resides
resource "aws_subnet" "priv-subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.priv_subnet_cidr_block_1
  availability_zone = "${var.region}b"

  tags = {
    Name = "backend-private-subnet1"
  }
}

resource "aws_subnet" "priv-subnet-2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.priv_subnet_cidr_block_2
  availability_zone = "${var.region}c"

  tags = {
    Name = "backend-private-subnet2"
  }
}

#Adding an internet gateway to the VPC to allow communication between the VPC and the internet.
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "backend-igw"
  }
}


#Creating a route table and associating it with the subnets to allow communication between the subnets and the internet gateway.
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "local"
  }

  tags = {
    Name = "backend-route-table"
  }
}

#Linking the route table to the public subnet to allow communication between the public subnet and the internet gateway.
resource "aws_route_table_association" "pub-subnet_association" {
  subnet_id      = aws_subnet.pub-subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

#Creating a security group to allow inbound traffic on port 80 and 443 for the ALB.
resource "aws_security_group" "my_security_group" {
  name        = "backend-sg"
  description = "Allow inbound traffic on port 80 and 443"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creating an s3 bucket to serve as the remote state backend
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

#Adding ownership controls to the S3 bucket to ensure that the bucket owner has full control over the objects in the bucket.
resource "aws_s3_bucket_ownership_controls" "my_bucket_ownership" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#Setting the ACL of the S3 bucket to private to ensure that only the bucket owner has access to the objects in the bucket.
resource "aws_s3_bucket_acl" "my_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.my_bucket_ownership]  
  bucket = aws_s3_bucket.my_bucket.id
  acl    = "private"
}


#Enabling versioning on the S3 bucket to keep multiple versions of an object in the same bucket.
resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  bucket = aws_s3_bucket.my_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

#Enabling object lock on the S3 bucket to prevent objects from being deleted or overwritten for a specified period of time.
resource "aws_s3_bucket_object_lock_configuration" "my_bucket_lock" {
  bucket = aws_s3_bucket.my_bucket.id
  depends_on = [aws_s3_bucket_versioning.my_bucket_versioning]

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}

#Creating a KMS key to encrypt the S3 bucket and enabling server-side encryption on the S3 bucket using the KMS key.
resource "aws_kms_key" "my_kms_key" {
  description             = var.kms_key
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "My KMS Key"
    Environment = "Dev"
  }
}

#Enabling server-side encryption on the S3 bucket using the KMS key created above.
resource "aws_s3_bucket_server_side_encryption_configuration" "my_bucket_encryption" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.my_kms_key.arn
    }
  }
}