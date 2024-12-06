terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.80.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# create instance on default vpc
resource "aws_instance" "ubuntu" {
  ami           = "ami-0dc44556af6f78a7b"
  instance_type = "t2.micro"
  key_name      = "multi-key"
  security_groups = [aws_security_group.allow_ssh.name]


  tags = {
    Name = "sexy-ubuntu"
  }
}

resource "aws_security_group" "allow_ssh" {
    name = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "22"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}