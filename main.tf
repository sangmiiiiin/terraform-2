terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.80.0"
    }
  }
}

# AWS 프로바이더 사용
provider "aws" {
  region = "ap-northeast-2" # 서울 리전
}

# VPC 생성
resource "aws_vpc" "sangmin-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "sangmin-vpc"
  }
}

# public subnet 생성
resource "aws_subnet" "ecr-public-subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.sangmin-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.sangmin-vpc.cidr_block, 8, count.index + 1)
  availability_zone       = ["ap-northeast-2a", "ap-northeast-2c"][count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = count.index == 0 ? "ecr-pub-subnet-2a" : "ecr-pub-subnet-2c"
  }
}

# private subnet 생성
resource "aws_subnet" "ecr-private-subnet" {
  count             = 4
  vpc_id            = aws_vpc.sangmin-vpc.id
  cidr_block        = cidrsubnet(aws_vpc.sangmin-vpc.cidr_block, 8, count.index + 3)
  availability_zone = ["ap-northeast-2a", "ap-northeast-2c"][count.index % 2]

  tags = {
    Name = lookup(
      {
        0 = "ecr-pri-subnet-2a-1"
        1 = "ecr-pri-subnet-2c-2"
        2 = "ecr-pri-subnet-2a-3"
        3 = "ecr-pri-subnet-2c-4"
      },
      count.index,
      "default-subnet-name"
    )
  }
}

resource "aws_internet_gateway" "ecr-igw" {
  vpc_id = aws_vpc.sangmin-vpc.id

  tags = {
    Name = "ecr-igw"
  }
}

resource "aws_route_table" "ecr-igw-rt" {
  vpc_id = aws_vpc.sangmin-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecr-igw.id
  }

  tags = {
    Name = "ecr-igw-rt"
  }
}

# public subnet 1에 라우팅 테이블 연결
resource "aws_route_table_association" "ecr-pub-subnet-2a-rt-assoc" {
  subnet_id      = aws_subnet.ecr-public-subnet[0].id
  route_table_id = aws_route_table.ecr-igw-rt.id
}

# public subnet 2에 라우팅 테이블 연결
resource "aws_route_table_association" "ecr-pub-subnet-2c-rt-assoc" {
  subnet_id      = aws_subnet.ecr-public-subnet[1].id
  route_table_id = aws_route_table.ecr-igw-rt.id
}

# create instance on sangmin-vpc (bastion)
data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }

  owners = ["137112412989"]

}

# 보안 그룹 생성
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic and all outbound traffic"

  tags = {
    Name = "allow_ssh"
  }
}

# Ingress Rule: SSH 접속 허용 (사용자의 IP)
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0" # SSH를 허용할 IP
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Engress Rule: anywhere 허용
resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0" # 모든 IPv4 트래픽 허용
  # from_port         = 0
  # to_port           = 0
  ip_protocol = "-1" # 모든 프로토콜 허용
}

resource "aws_instance" "bastion" {
  ami             = data.aws_ami.al-recent.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.allow_ssh.name]
  key_name = "multi-key"
  availability_zone = aws_subnet.ecr-public-subnet[0].availability_zone
  tags = {
    Name = "bastion"
  }

}