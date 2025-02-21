{
  "builders": [
    {
      "type": "amazon-ebs",
      "region": "us-west-2",
      "source_ami_filter": {
        "filters": {
          "name": "amzn2-ami-kernel-*-x86_64",
          "virtualization-type": "hvm",
          "root-device-type": "ebs"
        },
        "owners": ["amazon"],
        "most_recent": true
      },
      "instance_type": "t3.micro",
      "ssh_username": "ec2-user",
      "ami_name": "go-app-with-cloudwatch-{{timestamp}}",
      "ami_description": "Pre-baked AMI with Go and CloudWatch agent",
      "tags": {
        "Name": "go-app-with-cloudwatch"
      }
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "inline": [
        "sudo yum update -y",
        // 1) Install Go
        "curl -OL https://go.dev/dl/go1.20.5.linux-amd64.tar.gz",
        "sudo tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz",
        "echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh",
        "source /etc/profile.d/go.sh",

        // 2) Install Git
        "sudo yum install -y git",

        // 3) Clone your Go server code
        "git clone https://github.com/RuidiH/CS6650HW6_GO.git /home/ec2-user/go-server",
        "cd /home/ec2-user/go-server",

        // 4) Build the server
        "/usr/local/go/bin/go build -o /home/ec2-user/go-server/demo-server main.go",

        // 5) Install the CloudWatch Agent
        "sudo yum install -y amazon-cloudwatch-agent"
      ]
    },
    {
      "type": "file",
      "source": "cloudwatch-agent-config.json",
      "destination": "/tmp/cloudwatch-agent-config.json"
    },
    {
      "type": "shell",
      "inline": [
        // 6) Move config and set up the agent to start at boot
        "sudo cp /tmp/cloudwatch-agent-config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json",
        "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop",
        "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -m ec2",

        // 7) Create a Systemd service for the Go app to start on boot
        "cat << 'EOF' | sudo tee /etc/systemd/system/go-demo.service\n[Unit]\nDescription=Go Demo Server\nAfter=network.target\n[Service]\nType=simple\nExecStart=/home/ec2-user/go-server/demo-server\nRestart=always\nUser=ec2-user\n[Install]\nWantedBy=multi-user.target\nEOF",
        "sudo systemctl daemon-reload",
        "sudo systemctl enable go-demo.service",

        // Stop the service so it doesn't keep running during image creation
        "sudo systemctl stop go-demo.service"
      ]
    }
  ]
}
