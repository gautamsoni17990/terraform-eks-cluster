variable "S3_BUCKET_NAME" {
  type = string
}

variable "STATE_FILE_NAME" {
  type = string
}

variable "AWS_REGION" {
  type = string
}

variable "EKS_ROLE_NAME" {
  type    = string
  default = "gautam-eks-iam-role"
}

variable "WORKER_ROLE_NAME" {
  type = string
  default = "gautam-eks-worker-iam-role"
}


variable "EKS_CLUSTER_NAME" {
  type = string
}

variable "EKS_NODE_GROUP_NAME" {
  type = string
}


variable "MAIN_VPC_CIDR" {
  type = string
  default = "10.0.0.0/16"
}

variable "PUBLIC_SUBNETS" {
  type = string
  default = "10.0.1.0/24"
}

variable "PRIVATE_SUBNETS" {
  type = string
  default = "10.0.2.0/24"
}

variable "PRIVATE_AZ" {
  type = string
  default = "ap-south-1a"
}

variable "PUBLIC_AZ" {
  type = string
  default = "ap-south-1b"
}

variable "DESIRED_STATE" {
  type = number
}

variable "MAX_SIZE" {
  type = number
}

variable "MIN_SIZE" {
  type = number
}
