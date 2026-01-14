# === Create VPC ===
resource "aws_vpc" "main-vpc" {

  # IP A Private usable range
  cidr_block = var.vpc_cidr

  # Use DNS in VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# === Create SUBNETS ===
# 2 Azs
# 2 x Public, WEB, APP, DB

# Create public subnets
resource "aws_subnet" "public_sb" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.value.name
  }
}

# Create private subnets
resource "aws_subnet" "private_sb" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.value.name
  }
}

# Create database subnets
resource "aws_subnet" "database_sb" {
  for_each = var.database-subnets

  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.value.name
  }
}

# === CREATE GW IG & NAT GW ===

# Create IG
resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main-vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create Elastic IP for NAT GW
resource "aws_eip" "eip_nat" {

  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {

  # elastic ip association
  allocation_id = aws_eip.eip_nat.id
  # provision in subnet public a
  subnet_id = aws_subnet.public_sb["public_a"].id

  tags = {
    Name = "${var.project_name}-natgw"
  }
  # Make shure we hava an IGW before provisioning NATGW
  depends_on = [aws_internet_gateway.igw]

}

# === ROUTE TABLE CREATION ===

# 1 Public (Public)
# 1 Private (APP, WEB)
# 1 DB (DB)

# Create rt public -> IGW
resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main-vpc.id

  # Create and add a ROUTE 
  # all outgoing traffic to the IG
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}
# Create only private RT, no route yet
resource "aws_route_table" "private-rt" {

  vpc_id = aws_vpc.main-vpc.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Create route to NAT and attach to private rt
resource "aws_route" "route-nat" {

  route_table_id         = aws_route_table.private-rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# Create rt for db, no route explicitly
# Implicit AWS create local rt (no need to create it)
resource "aws_route_table" "database-rt" {

  vpc_id = aws_vpc.main-vpc.id

  tags = {
    Name = "${var.project_name}-database-rt"
  }
}

# === Associate  Subnets <-> Routetables ===
#  8 associations -> each subent must be associated to rt

# === PUBLIC ASSOCIATIONS ===
resource "aws_route_table_association" "as-public" {
  for_each = aws_subnet.public_sb

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# === PRIVATE  ASSOCIATIONS ===
resource "aws_route_table_association" "as-private" {
  for_each = aws_subnet.private_sb

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-rt.id
}

# === DB  ASSOCIATIONS ===
resource "aws_route_table_association" "as-database" {
  for_each = aws_subnet.database_sb

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database-rt.id
} 