terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "my-s3-bucket-terraform-7508692763"
    key            = "my-terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

# Create the S3 bucket for terraform state file.

# Create the VPC section so that we can create our EKS cluster in separate VPC only.

resource "aws_vpc" "Main" {
  cidr_block       = var.MAIN_VPC_CIDR
  instance_tenancy = "default"
  tags = {
    Name = "My-VPC"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.Main.id
  tags = {
    Name = "My-IGW"
  }
}

/*
resource "aws_eip" "nateIP" {
  vpc = true
}
*/

/*
resource "aws_nat_gateway" "NATgw" {
  allocation_id = aws_eip.nateIP.id
  subnet_id     = aws_subnet.publicsubnet.id
  tags = {
    Name = "My-NAT-GW"
  }

  depends_on = [
    aws_subnet.publicsubnet,
    aws_subnet.privatesubnet
  ]
}
*/


resource "aws_subnet" "publicsubnet" {
  vpc_id                  = aws_vpc.Main.id
  cidr_block              = var.PUBLIC_SUBNETS
  availability_zone       = var.PUBLIC_AZ
  map_public_ip_on_launch = true
  tags = {
    Name = "My-Public-Subnet"
  }
}

resource "aws_subnet" "privatesubnet" {
  vpc_id            = aws_vpc.Main.id
  cidr_block        = var.PRIVATE_SUBNETS
  availability_zone = var.PRIVATE_AZ
  map_public_ip_on_launch = true
  tags = {
    Name = "My-Private-Subnet"
  }
}

resource "aws_route_table" "PublicRT" {
  vpc_id = aws_vpc.Main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "My-Public-RT"
  }

  depends_on = [
    aws_internet_gateway.IGW
  ]
}


resource "aws_route_table" "PrivateRT" {
  vpc_id = aws_vpc.Main.id
  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "My-Private-RT"
  }
}

resource "aws_route_table_association" "PublicRTassociation" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.PublicRT.id
}

resource "aws_route_table_association" "PrivateRTassociation" {
  subnet_id      = aws_subnet.privatesubnet.id
  route_table_id = aws_route_table.PrivateRT.id
}


resource "aws_iam_role" "eks-iam-role" {
  name = var.EKS_ROLE_NAME
  path = "/"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Principal": {
    "Service": "eks.amazonaws.com"
   },
   "Action": "sts:AssumeRole"
  }
 ]
}
EOF
  tags = {
    Name = "My-EKS-Role"
  }

}


resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.eks-iam-role.name
}


resource "aws_eks_cluster" "eks-cluster" {
  name     = var.EKS_CLUSTER_NAME
  role_arn = aws_iam_role.eks-iam-role.arn
  version  = "1.23"

  vpc_config {
    subnet_ids = [aws_subnet.publicsubnet.id, aws_subnet.privatesubnet.id]
  }

  depends_on = [
    aws_iam_role.eks-iam-role,
  ]
  tags = {
    Name = "My-EKS-Cluster"
  }

}

resource "aws_iam_role" "workernodes" {
  name = var.WORKER_ROLE_NAME
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  tags = {
    Name = "My-EKS-Worker-Role"
  }
}


resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workernodes.name
}

data "aws_key_pair" "key_pair" {
  key_name = "eks-demo"
}

resource "aws_eks_node_group" "worker-node-group" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = var.EKS_NODE_GROUP_NAME
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = [aws_subnet.publicsubnet.id, aws_subnet.privatesubnet.id]
  instance_types  = ["t3.medium"]
  disk_size       = "20"
  version         = "1.23"

  scaling_config {
    desired_size = var.DESIRED_STATE
    max_size     = var.MAX_SIZE
    min_size     = var.MIN_SIZE
  }

  remote_access {
    ec2_ssh_key = data.aws_key_pair.key_pair.key_name
  }

  tags = {
    Name = "My-EKS-Worker-Node-Group"
  }

  depends_on = [
    aws_iam_role.workernodes,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.EC2InstanceProfileForImageBuilderECRContainerBuilds,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]
}
