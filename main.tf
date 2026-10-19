#Setting up the custom VPC with the specified cidr block variable and creating 2 subnet within the VPC in 2 availability zones.

resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.vpc_name
  }
}


#Creating a public subnet where the ALB will resides
resource "aws_subnet" "pub-subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.pub_subnet_cidr_block
  availability_zone = "${var.region}a"

  tags = {
    Name = "public-subnet1"
  }
}

resource "aws_subnet" "pub-subnet-2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.pub_subnet_cidr_block_2
  availability_zone = "${var.region}b"

  tags = {
    Name = "public-subnet2"
  }
}

#Creating a private subnet where the ECSs will resides
resource "aws_subnet" "priv-subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.priv_subnet_cidr_block_1
  availability_zone = "${var.region}a"

  tags = {
    Name = "private-subnet1"
  }
}

#creating the 2nd subnet
resource "aws_subnet" "priv-subnet-2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.priv_subnet_cidr_block_2
  availability_zone = "${var.region}b"

  tags = {
    Name = "private-subnet2"
  }
}

#Adding an internet gateway to the VPC to allow communication between the VPC and the internet.
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "internet-gateway"
  }
}

#Adding anelastic IP so that the NAT gateway can be accessed from the internet.
resource "aws_eip" "my_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.my_igw]
}

#creating a NAT gateway in the public subnet to allow the ECSs in the private subnets to access the internet.
resource "aws_nat_gateway" "my_nat_gateway" {
  subnet_id     = aws_subnet.pub-subnet.id
  allocation_id = aws_eip.my_eip.id

  tags = {
    Name = "nat-gateway"
  }
}


#Creating a route table and associating it with the subnets to allow communication between the subnets and the internet gateway.
resource "aws_route_table" "pub_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

#Linking the route table to the public subnets to allow communication between the public subnet and the internet gateway.
resource "aws_route_table_association" "pub-subnet_association" {
  subnet_id      = aws_subnet.pub-subnet.id
  route_table_id = aws_route_table.pub_route_table.id
}

resource "aws_route_table_association" "pub-subnet-2_association" {
  subnet_id      = aws_subnet.pub-subnet-2.id
  route_table_id = aws_route_table.pub_route_table.id
}

#Creating a private route table for the private subnets
resource "aws_route_table" "priv_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

#Adding a route to the private route table to allow communication between the private subnets and the NAT gateway.
resource "aws_route" "priv_route" {
  route_table_id         = aws_route_table.priv_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.my_nat_gateway.id  # NOTE 3
}

#Linking the private route table to the private subnets.
resource "aws_route_table_association" "priv-subnet_association" {
  subnet_id      = aws_subnet.priv-subnet.id
  route_table_id = aws_route_table.priv_route_table.id
}

resource "aws_route_table_association" "priv-subnet-2_association" {
  subnet_id      = aws_subnet.priv-subnet-2.id
  route_table_id = aws_route_table.priv_route_table.id
}

#Creating a security group to allow inbound traffic on port 80 and 443 for the ALB.
resource "aws_security_group" "my_security_group" {
  name        = "alb-security-group"
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

#Creating the ecs service security group to isolate the service
resource "aws_security_group" "service_sg" {
  name        = "svc-security-group"
  description = "Allow inbound traffic on port 8008"
  vpc_id      = aws_vpc.my_vpc.id

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
    Name        = "My-KMS-Key"
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

#Creating an ECS task definition to run a containerized docker application on Fargate.
resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = var.ecs_task_definition_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "nginx-app"
      image     = var.docker-image
      essential = true
      portMappings = [
        {
          containerPort = 8008
          hostPort      = 8008
        }
      ]
    }
  ])
}

#Creating an ECS service to run the task definition on Fargate and associating it with the security group created above.
resource "aws_ecs_service" "my_ecs_service" {

  depends_on = [aws_ecs_task_definition.my_task_definition]

  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.my_ecs_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.priv-subnet.id, aws_subnet.priv-subnet-2.id]
    security_groups = [aws_security_group.service_sg.id]
    assign_public_ip = false
  }
}

#Creating an ECS cluster to run the ECS service on Fargate.
resource "aws_ecs_cluster" "my_ecs_cluster" {
  name = var.ecs_cluster_name
}
