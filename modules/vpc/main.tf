# ------------------------
# modules/vpc/main.tf
# ------------------------

# Create Virtual Private Cloud 
resource "aws_vpc" "infra_vpc" {
  cidr_block           = var.infra_vpc_cidr
  enable_dns_support   = true  # Enable DNS resolution in the VPC
  enable_dns_hostnames = true  # Enable hostnames for instances launched in the VPC

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-vpc"
  })
}

# Create an Internet Gateway attached to the VPC
resource "aws_internet_gateway" "infra_igw" {
  vpc_id = aws_vpc.infra_vpc.id

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-igw"
  })

  depends_on = [aws_vpc.infra_vpc]
}

# Create Public Subnets in each Availability Zone
resource "aws_subnet" "infra_public_subnets" {
  for_each = { for idx, az in var.infra_subnet_azs : idx => az } # Loop over each AZ from variable infra_subnet_azs

  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.infra_public_subnet_cidrs[each.key]
  availability_zone       = each.value
  map_public_ip_on_launch = true  # Automatically assign public IPs to instances launched in these subnets

  tags = merge(var.infra_tags, {
    Name                                              = "${var.infra_environment}-${var.infra_project_name}-public-${each.key}"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${var.infra_cluster_name}" = "owned"
  })
  depends_on = [aws_vpc.infra_vpc]
}

# Create Private Subnets in each Availability Zone
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
  depends_on = [aws_vpc.infra_vpc]
}

# Allocate an Elastic IP for NAT

resource "aws_eip" "infra_nat_eip" {
  count  = 1
  domain = "vpc"

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-eip"
  })
  depends_on = [aws_vpc.infra_vpc]
}

# Create a NAT Gateway in the public subnet (allows private subnet instances internet access)
resource "aws_nat_gateway" "infra_nat_gw" {
  allocation_id = aws_eip.infra_nat_eip[0].id
  subnet_id     = aws_subnet.infra_public_subnets["0"].id  # NAT Gateway must be in a public subnet to provide internet access

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-nat-gw"
  })
  depends_on = [aws_vpc.infra_vpc, 
    aws_eip.infra_nat_eip
    ]
}

# Route table for Public subnets
resource "aws_route_table" "infra_public_rt" {
  vpc_id = aws_vpc.infra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"   # Route all internet-bound traffic (0.0.0.0/0) through the Internet Gateway
    gateway_id = aws_internet_gateway.infra_igw.id
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-public-rt"
  })
  depends_on = [aws_vpc.infra_vpc]
}

# Associate each public subnet to the public route table
resource "aws_route_table_association" "infra_public_rt_assoc" {
  for_each = aws_subnet.infra_public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.infra_public_rt.id

  depends_on = [aws_vpc.infra_vpc,
    aws_subnet.infra_public_subnets
  ]
}

# Route table for Private subnets
resource "aws_route_table" "infra_private_rt" {
  vpc_id = aws_vpc.infra_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"   # Route internet-bound traffic from private subnets through the NAT Gateway
    nat_gateway_id = aws_nat_gateway.infra_nat_gw.id
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_environment}-${var.infra_project_name}-private-rt"
  })
  depends_on = [aws_vpc.infra_vpc]
}

# Associate each private subnet to the private route table
resource "aws_route_table_association" "infra_private_rt_assoc" {
  for_each = aws_subnet.infra_private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.infra_private_rt.id

  depends_on = [aws_vpc.infra_vpc,
      aws_subnet.infra_private_subnets
      ]
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

