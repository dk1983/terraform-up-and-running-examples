resource "aws_instance" "tf-example-instance" {
  ami                    = "ami-01f08ef3e76b957e5"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]

  user_data              = <<-EOF
            #!/bin/bash
            echo "hello world" > index.html
            nohup busybox httpd -f -p 8080 &
            EOF
            
  tags = {
    Name    = "TF Example"
    Chapter = "Chapter 2"
  }
}

resource "aws_security_group" "instance" {
  name = "tf-example-instance"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}