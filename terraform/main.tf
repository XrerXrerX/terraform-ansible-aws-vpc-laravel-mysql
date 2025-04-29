terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = "region"
  access_key = "access_key"
  secret_key = "secret_key"
}


#  VPC
resource "aws_vpc" "prod" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "prod-vpc"
  }
}

#Subnet PUBLIC (untuk bastion)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "region"
  tags = {
    Name = "prod-public"
  }
}

#Subnet PRIVATE (untuk webserver/db)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "region"
  tags = {
    Name = "prod-private"
  }
}


# Internet Gateway untuk Subnet Public
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "prod-igw"
  }
}


#Route Table untuk Subnet Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "prod-public-rt"
  }
}

#Route Table Association untuk Subnet Public
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from trusted IP"
  vpc_id      = aws_vpc.prod.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["your office ip"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["your office ip"] # Ganti YOUR_PUBLIC_IP, jangan pakai 0.0.0.0/0 di production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nginx_proxy_sg" {
  name        = "nginx-proxy-sg"
  description = "Allow HTTP/HTTPS from anywhere"
  vpc_id      = aws_vpc.prod.id


  ingress {
    description = "SSH from Bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

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


resource "aws_security_group" "laravel_private_sg" {
  name        = "laravel-private-sg"
  description = "Allow HTTP from Nginx Proxy, SSH from Bastion"
  vpc_id      = aws_vpc.prod.id

  ingress {
    description = "HTTP from Nginx Proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.nginx_proxy_sg.id]
  }
  ingress {
    description = "SSH from Bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql_private_sg" {
  name        = "mysql-private-sg"
  description = "Allow MySQL from Laravel Private, SSH from Bastion"
  vpc_id      = aws_vpc.prod.id

  ingress {
    description = "HTTP from Nginx bastion for check phpmyadmin"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "MySQL from Laravel Private"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.laravel_private_sg.id]
  }
  ingress {
    description = "SSH from Bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#EC2 Bastion Host (public subnet, public IP):
resource "aws_instance" "bastion" {
  ami                    = "ami-aws"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "main-key"
  # associate_public_ip_address = true   # boleh dihapus, boleh tetap (EIP akan override)
  tags = {
    Name = "BastionHost"
  }
}

resource "aws_eip" "bastion_eip" {
  vpc      = true
  instance = aws_instance.bastion.id
  tags = {
    Name = "Bastion-EIP"
  }
}


# Elastic IP untuk NAT Gateway (harus baru, BUKAN dipakai bastion!)
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = {
    Name = "NAT-EIP"
  }
}

# NAT Gateway (ditempatkan di subnet public)
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "prod-natgw"
  }
}

# Route table untuk private subnet, keluar lewat NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "prod-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}



# EC2 laravel (private subnet, TIDAK ada public IP):
resource "aws_instance" "laravel_private" {
  ami                    = "ami-aws"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.laravel_private_sg.id]
  key_name               = "main-key"
  associate_public_ip_address = false
  tags = {
    Name = "laravelprivate"
  }
  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install nginx -y
                sudo systemctl start nginx
                sudo bash -c 'echo Private laravel > /var/www/html/index.html'
                EOF
}
# EC2 Database (private subnet, TIDAK ada public IP):
resource "aws_instance" "mysql_private" {
  ami                    = "ami-aws"
  instance_type          = "t2.micro"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.mysql_private_sg.id]
  key_name               = "main-key"
  associate_public_ip_address = false
  tags = {
    Name = "WebPrivate"
  }
  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install nginx -y
                sudo systemctl start nginx
                sudo bash -c 'echo Private mysql > /var/www/html/index.html'
              EOF
}



resource "aws_instance" "nginx_public" {
  ami                    = "ami-aws"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nginx_proxy_sg.id] # bisa buat sg khusus nginx
  key_name               = "main-key"
  associate_public_ip_address = true
  tags = {
    Name = "Nginx-Public"
  }
  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install nginx -y
                sudo systemctl start nginx
                sudo bash -c 'echo Public Nginx > /var/www/html/index.html'
              EOF
}

resource "aws_eip" "nginx_eip" {
  instance = aws_instance.nginx_public.id
  vpc      = true
  depends_on = [aws_instance.nginx_public]
}


#output
output "bastion_public_ip" {
  description = "Public IP Bastion Host"
  value       = aws_eip.bastion_eip.public_ip
}


output "laravel_private_ip" {
  description = "Private IP instance Laravel"
  value       = aws_instance.laravel_private.private_ip
}

output "nginx_public_ip" {
  description = "Public IP untuk Nginx Reverse Proxy"
  value       = aws_eip.nginx_eip.public_ip
}

output "nginx_proxy_private_ip" {
  description = "Private IP untuk Nginx Reverse Proxy"
  value       = aws_instance.nginx_public.private_ip
}

output "mysql_private_ip" {
  description = "Private IP instance MySQL"
  value       = aws_instance.mysql_private.private_ip
}
