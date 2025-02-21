packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# ------------------------------------------------------------------------------
# Source Configuration (Amazon EBS)
# ------------------------------------------------------------------------------
source "amazon-ebs" "go_app_with_cloudwatch" {
  region  = "us-west-2"

  # We'll use a filter to pick the latest Amazon Linux 2 AMI
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-2.0.*-x86_64-gp2"
      "virtualization-type" = "hvm"
      "root-device-type"    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  instance_type    = "t3.micro"
  ssh_username     = "ec2-user"
  ami_name         = "go-app-with-cloudwatch-{{timestamp}}"
  ami_description  = "Pre-baked AMI with Go and CloudWatch agent"

  tags = {
    Name = "go-app-with-cloudwatch"
  }
}

# ------------------------------------------------------------------------------
# Build Block: Provisioners
# ------------------------------------------------------------------------------
build {
  name    = "build-go-app-with-cloudwatch"
  sources = [
    "source.amazon-ebs.go_app_with_cloudwatch"
  ]

  # ----------------------------------------------------------------------------
  # First shell provisioner: install dependencies, clone, build
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    # Comments in HCL are placed outside the array
    inline = [
      "sudo yum update -y",

      # 1) Install Go
      "curl -OL https://go.dev/dl/go1.20.5.linux-amd64.tar.gz",
      "sudo tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz",
      "echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh",
      "source /etc/profile.d/go.sh",

      # 2) Install Git
      "sudo yum install -y git",

      # 3) Clone your Go server code
      "git clone https://github.com/RuidiH/CS6650HW6_GO /home/ec2-user/go-server",
      "cd /home/ec2-user/go-server",

      # 4) Build the server
      "/usr/local/go/bin/go build -o /home/ec2-user/go-server/CS6650HW6_GO main.go",

      # 5) Install the CloudWatch Agent
      "sudo yum install -y amazon-cloudwatch-agent"
    ]
  }

  # ----------------------------------------------------------------------------
  # File provisioner: upload CloudWatch agent config
  # ----------------------------------------------------------------------------
  provisioner "file" {
    source      = "cloudwatch-agent-config.json"
    destination = "/tmp/cloudwatch-agent-config.json"
  }

  # ----------------------------------------------------------------------------
  # Second shell provisioner: configure CloudWatch Agent + systemd service
  # ----------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      # 0) (Optional) Kill background yum so it doesn't lock:
      "sudo pkill -9 yum || true",
      "sudo rm -f /var/run/yum.pid || true",

      # 1) Now run yum update
      "sudo yum update -y",

      # 2) Install Go
      "curl -OL https://go.dev/dl/go1.20.5.linux-amd64.tar.gz",
      "sudo tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz",
      "echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh",
      "sudo chmod 644 /etc/profile.d/go.sh",              # Ensure read permission
      "source /etc/profile.d/go.sh",                      # Now you can safely source it

      # 3) Install Git
      "sudo yum install -y git",

      # 4) Clone your Go server code
      "git clone https://github.com/RuidiH/CS6650HW6_GO /home/ec2-user/go-server",
      "cd /home/ec2-user/go-server",

      # 5) Build the server
      "/usr/local/go/bin/go build -o /home/ec2-user/go-server/CS6650HW6_GO main.go",

      # 6) Install CloudWatch agent
      "sudo yum install -y amazon-cloudwatch-agent"
    ]
  }
}
