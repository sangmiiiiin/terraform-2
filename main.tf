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