# ------------------------
# modules/vpc/main.tf
# ------------------------

resource "aws_vpc" "infra_vpc" {
  cidr_block           = var.infra_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-vpc"
  })
}

resource "aws_internet_gateway" "infra_igw" {
  vpc_id = aws_vpc.infra_vpc.id

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-igw"
  })
}

resource "aws_subnet" "infra_public_subnets" {
  for_each = { for idx, az in var.infra_subnet_azs : idx => az }

  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.infra_public_subnet_cidrs[each.key]
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = merge(var.infra_tags, {
    Name                                              = "${var.infra_environment}-${var.infra_project_name}-public-${each.key}"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${var.infra_cluster_name}" = "owned"
  })
}

resource "aws_subnet" "infra_private_subnets" {
  for_each = { for idx, az in var.infra_subnet_azs : idx => az }

  vpc_id            = aws_vpc.infra_vpc.id
  cidr_block        = var.infra_private_subnet_cidrs[each.key]
  availability_zone = each.value

  tags = merge(var.infra_tags, {
    Name                                              = "${var.infra_environment}-${var.infra_project_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${var.infra_cluster_name}" = "owned"
  })
}

resource "aws_eip" "infra_nat_eip" {
  count  = 1
  domain = "vpc"

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-eip"
  })
}

resource "aws_nat_gateway" "infra_nat_gw" {
  allocation_id = aws_eip.infra_nat_eip[0].id
  subnet_id     = aws_subnet.infra_public_subnets["0"].id

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-nat-gw"
  })
}

resource "aws_route_table" "infra_public_rt" {
  vpc_id = aws_vpc.infra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.infra_igw.id
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-public-rt"
  })
}

resource "aws_route_table_association" "infra_public_rt_assoc" {
  for_each = aws_subnet.infra_public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.infra_public_rt.id
}

resource "aws_route_table" "infra_private_rt" {
  vpc_id = aws_vpc.infra_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.infra_nat_gw.id
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-private-rt"
  })
}

resource "aws_route_table_association" "infra_private_rt_assoc" {
  for_each = aws_subnet.infra_private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.infra_private_rt.id
}

resource "aws_security_group" "infra_eks_sg" {
  name        = "${var.infra_environment}-${var.infra_project_name}-eks-sg"
  description = "Allow access from the jumpserver"
  vpc_id      = aws_vpc.infra_vpc.id

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-eks-sg"
  })
}

