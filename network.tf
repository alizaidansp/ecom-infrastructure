
# for file in *.tf; do echo "===== $file =====" >> output.txt; cat "$file" >> output.txt; echo "" >> output.txt; done

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" # This VPC has 65,536 IPs (10.0.0.0 - 10.0.255.255)
}

# Convert single subnets to multiple AZs
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = "${var.region}${count.index == 0 ? "a" : "b"}"
  #   Parent CIDR: aws_vpc.main.cidr_block (your VPC's CIDR block, e.g., 10.0.0.0/16)
  # New Bits: 8 (number of additional bits to add to the prefix)
  # Subnet Number: count.index (0-based index of the subnet in the list)
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone = "${var.region}${count.index == 0 ? "a" : "b"}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Use the first public subnet
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.ecs_sg.id]
  subnet_ids         = aws_subnet.private[*].id # Use [*] to get all subnet IDs
}

resource "aws_vpc_endpoint" "ecr" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.ecs_sg.id]
  subnet_ids         = aws_subnet.private[*].id # Use [*] to get all subnet IDs
}

# Add to network.tf if missing
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.eu-west-1.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.ecs_sg.id]
  subnet_ids         = aws_subnet.private[*].id
}
# terraform fmt  # Format the code properly
# terraform validate  # Validate the Terraform syntax
# terraform apply  # Apply the changes
