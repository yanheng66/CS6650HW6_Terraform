############
# Provider
############
provider "aws" {
  region  = "us-west-2"  # or any preferred region
  # If Cloud9 is already set up with an IAM role that allows provisioning,
  # you likely don't need explicit access/secret keys. 
  # Otherwise, you can specify or set environment variables.
  # access_key = "<YOUR-ACCESS-KEY>"
  # secret_key = "<YOUR-SECRET-KEY>"
}

############
# Variables
############
variable "db_username" {
  type    = string
  default = "mydbuser"
}

variable "db_password" {
  type    = string
  default = "mydbpass123"
}

variable "ami_id" {
  type = string
  default = "ami-08e4e35cccc6189f4"
}
############
# VPC & Subnet
############
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "demo-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = {
    Name = "demo-igw"
  }
}

resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block             = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"  # pick an AZ in your region
  tags = {
    Name = "demo-subnet"
  }
}

resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = {
    Name = "demo-rt"
  }
}

resource "aws_route" "demo_route" {
  route_table_id         = aws_route_table.demo_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "demo_rta" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_route_table.id
}

############
# Security Groups
############
# For the EC2 instances that will run the Go server
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-demo-sg"
  description = "Allow inbound traffic from ALB and SSH"
  vpc_id      = aws_vpc.demo_vpc.id

  # Allow inbound HTTP from ALB (or all for quick testing).
  ingress {
    description      = "HTTP from ALB"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  # For demo. In production, restrict to the ALB SG.
  }

  # Allow inbound SSH for debugging
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Outbound to anywhere
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-demo-sg"
  }
}

# For RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-demo-sg"
  description = "Allow MySQL inbound from EC2 SG"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description            = "MySQL access from ec2_sg"
    from_port              = 3306
    to_port                = 3306
    protocol               = "tcp"
    security_groups        = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-demo-sg"
  }
}

############
# RDS MySQL
############
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "demo-db-subnet-group"
  subnet_ids = [aws_subnet.demo_subnet.id]
  tags = {
    Name = "demo-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql_demo" {
  identifier             = "demo-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"    # For demo
  allocated_storage      = 20
  db_name                = "mydemodb"       # DB name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  deletion_protection    = false
  publicly_accessible    = true  # For demo; typically false in production

  tags = {
    Name = "demo-mysql-db"
  }
}

############
# ALB
############
resource "aws_lb" "demo_alb" {
  name               = "demo-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.demo_subnet.id]
  security_groups    = [aws_security_group.ec2_sg.id]  # For inbound rules, or a separate ALB SG
  ip_address_type    = "ipv4"

  tags = {
    Name = "demo-alb"
  }
}

resource "aws_lb_target_group" "demo_tg" {
  name        = "demo-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.demo_vpc.id
  target_type = "instance"
  health_check {
    port               = "traffic-port"
    protocol           = "HTTP"
    path               = "/count"    # The Go app route used for health checks
    matcher            = "200-399"
    healthy_threshold  = 2
    unhealthy_threshold = 2
    timeout            = 5
    interval           = 30
  }

  tags = {
    Name = "demo-tg"
  }
}

resource "aws_lb_listener" "demo_http_listener" {
  load_balancer_arn = aws_lb.demo_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_tg.arn
  }

  tags = {
    Name = "demo-alb-listener"
  }
}

############
# EC2 Auto Scaling Setup
############

# Example user_data script that:
# 1. Installs Go
# 2. Clones a public repo with your demo Go app
# 3. Builds and runs the server
data "template_file" "userdata" {
#   template = <<-EOF
#     #!/bin/bash
#     yum update -y
#     yum install -y git

#     # Install Go (example version 1.20.x)
#     wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz
#     tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz
#     echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
#     source /etc/profile

#     # optional: create a non-root user
#     # useradd -m demo
#     # su - demo

#     # Git clone your Go server
#     cd /root
#     git clone https://github.com/<YOUR-ORG>/<YOUR-GO-REPO>.git go-server
#     cd go-server

#     # set DB_DSN environment variable for MySQL
#     echo "export DB_DSN=\"${DB_DSN}\"" >> /etc/profile
#     source /etc/profile

#     # build and run (in background)
#     /usr/local/go/bin/go build -o demo-server main.go
#     nohup ./demo-server > /var/log/demo-server.log 2>&1 &
#     EOF

  vars = {
    DB_DSN = "${var.db_username}:${var.db_password}@tcp(${aws_db_instance.mysql_demo.address}:3306)/mydemodb"
  }
}

resource "aws_launch_template" "demo_lt" {
  name_prefix   = "demo-lt-"
  image_id      = var.ami_id  # Example Amazon Linux 2 in us-west-2. Update for your region
  instance_type = "t3.micro"

  user_data = base64encode(data.template_file.userdata.rendered)

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "demo-ec2"
    }
  }
}

resource "aws_autoscaling_group" "demo_asg" {
  name                = "demo-asg"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 2
  launch_template {
    id      = aws_launch_template.demo_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.demo_subnet.id]

  target_group_arns = [aws_lb_target_group.demo_tg.arn]

  tag {
      key                 = "Name"
      value               = "demo-ec2"
      propagate_at_launch = true
    }

  lifecycle {
    create_before_destroy = true
  }
}

############
# Outputs
############
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.demo_alb.dns_name
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.mysql_demo.address
}
