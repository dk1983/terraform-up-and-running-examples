data "aws_vpc" "default" {
  default = true
}

# Pg 63: Adding data source lookup the subnets in vpc
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
