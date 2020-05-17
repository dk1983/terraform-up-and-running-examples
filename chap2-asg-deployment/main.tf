# Pg 62: update launch config
resource "aws_launch_configuration" "example" {
  image_id        = "ami-01f08ef3e76b957e5"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"] #[aws_security_group.instance.id]

  user_data = <<-EOF
            #!/bin/bash
            echo "hello world" > index.html
            nohup busybox httpd -f -p ${var.server_port} &
            EOF

  # required when using a lunch configuration with an auto scaling group
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}

# Pg 62: update ASG
# Pg 68: set target_group_arn to point at new target group
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids # (pg 64)

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 8

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# Pg 66: adding ALB
# Pg 67: Tell aws_lb to use alb security group
# "internal = true" or get "Error creating application Load Balancer: InvalidSubnet: VPC vpc-726bfb0a has no internet gateway"
# https://github.com/hashicorp/terraform/issues/13587
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]
  internal           = true
}

# Pg 66: adding lb listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  # By default, return 404 page
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# Pg 59: Variable reference, setting port parameters of security group
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Pg 67: Add security group for ALB to allow incoming/outgoing traffic
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  #Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Pg 68: add lb target group to health check instances by periodically sending HTTP request
# to each instance. Unhealthy if it doesn't match "matcher"
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Pg 69: Create listener rules to tie everything together
# Adds a listener rule that sends requests that match any path to teh target group 
# that contains the ASG
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  # book version depricated
  # https://github.com/terraform-aws-modules/terraform-aws-atlantis/pull/89/commits/a9f64bbab88426adafdb20f3f048bc78af6f87f3
  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
