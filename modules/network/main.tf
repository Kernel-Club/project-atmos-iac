resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}
# The VPC is our own private network inside AWS. Everything else lives in it.
# DNS options must be on, because EKS nodes need DNS names to find the cluster.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}
# The Internet Gateway is the door between the VPC and the internet.
# It is free.

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
# Public subnets (one per availability zone): 10.0.0.0/24 and 10.0.1.0/24.
# The load balancer and the NAT Gateway live here, because they need a public IP.
# The tag "kubernetes.io/role/elb" tells Kubernetes: "you may put a public
# load balancer in this subnet".

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
# Private subnets: 10.0.10.0/24 and 10.0.11.0/24.
# The worker nodes (and our app) live here. They have no public IP,
# so nobody from the internet can connect to them directly.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
# A route table is a list of rules that says where traffic goes.
# Rule here: "all internet traffic (0.0.0.0/0) goes to the Internet Gateway".
# The association connects this rule list to each public subnet.

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}
# An Elastic IP is a fixed public IP address. The NAT Gateway needs one.
# "count = ... ? 1 : 0" means: create it only when enable_nat_gateway is true.
# Careful: an Elastic IP that is not attached to anything costs money.

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}
# The NAT Gateway lets private nodes go OUT to the internet
# (for example to call the OpenWeather API or pull Docker images),
# but nobody can come IN. We use ONE NAT for both DEV and PROD to save money.
# This is the most expensive part of the network (about $0.06 per hour).
# depends_on makes Terraform create the Internet Gateway first.

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
# Rule list for the private subnets: "all internet traffic goes to the NAT Gateway".
# "dynamic route" adds this rule only when NAT is enabled.
# Without NAT the private subnets have no way out to the internet.
