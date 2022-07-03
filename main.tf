#Creating Povider
provider "aws" {
  access_key = "aws-access-key"
  secret_key = "aws-secret-access_key"
  region     = "ap-southeast-1"
}

#Variable for ec2 key pairs ,you need to create one key pair and save it for this 
variable "ec2-key" {}

# Creating  VPC
resource "aws_vpc" "sai-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "SAI VPC"
  }
}

# Creating Public Subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.sai-vpc.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Public Subnet"
  }
}

# Creating Private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.sai-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Private Subnet"
  }
}

# Creating Main Internal Gateway for VPC
resource "aws_internet_gateway" "sai-igw" {
  vpc_id = aws_vpc.sai-vpc.id

  tags = {
    Name = "SAI-IGW"
  }
}

#Association Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.sai-igw]
  tags = {
    Name = "EIP for NAT-GW"
  }
}

#Creating NAT Gateway for VPC with public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NAT Gateway"
  }
}

# Creating Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sai-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sai-igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Associate Public Subnet to Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table for Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.sai-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Associate Private Subnet to Private Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

#Creating security groups for allow ssh incomming only
resource "aws_security_group" "ssh" {
  name        = "allow_ssh"
  description = "Allow ssh only "
  tags = {
    Name = "Allow ssh only"
  }
  vpc_id      = aws_vpc.sai-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

#Creating security groups for all ssh incomming and outgoing for all
resource "aws_security_group" "ingress_ssh_egress_all" {
  name        = "allow_in_ssh_and_egr_all"
  description = "Allow ingress ssh only and egress all"
  tags = {
    Name = "Allow incomming ssh only and outgoing all"
  }
  vpc_id      = aws_vpc.sai-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creating public-linux instance
resource "aws_instance" "public-linux" {
  ami = "ami-0c802847a7dd848c0"
  subnet_id = aws_subnet.public.id
  instance_type = "t2.micro"
  key_name = "${var.ec2-key}"
  associate_public_ip_address = true
  security_groups = [aws_security_group.ssh.id]
  tags = {
    Name = "Public-Linux"
  }
 
}

#Creating private-linux instance
resource "aws_instance" "private-linux" {
  ami = "ami-0c802847a7dd848c0"
  subnet_id = aws_subnet.private.id
  instance_type = "t2.micro"
  key_name = "${var.ec2-key}"
  associate_public_ip_address = false
  security_groups = [aws_security_group.ingress_ssh_egress_all.id]
  tags = {
    Name = "Private-Linux"
  }
 
}


