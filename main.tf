# Terraform configuration for deploying a basic EC2 instance on AWS

provider "aws" {
  region = "us-east-1" # Change this to your preferred region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "instance" {
  name        = "allow_ssh_dotnet"
  description = "Allow SSH and .NET inbound traffic"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (for .NET apps, e.g., Kestrel default port 5000)
  ingress {
    from_port   = 5000
    to_port     = 5000
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.instance.id]

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    # Install updates and required packages
    yum update -y

    # Install .NET 8 SDK and ASP.NET Core Runtime (Amazon Linux 2)
    rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
    yum install -y dotnet-sdk-8.0 aspnetcore-runtime-8.0

    # Optionally, clone and run your .NET project here:
    # git clone <your-repo-url> /home/ec2-user/app
    # cd /home/ec2-user/app
    # dotnet run --urls "http://0.0.0.0:5000"
    
    # Enable firewall access to port 5000 if using firewalld (Amazon Linux 2 does not enable by default)
    # firewall-cmd --zone=public --add-port=5000/tcp --permanent
    # firewall-cmd --reload
  EOF

  tags = {
    Name = "terraform-ec2-instance"
  }

  # Uncomment and specify your key name if you want SSH access
  # key_name = "your-key-name"
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}