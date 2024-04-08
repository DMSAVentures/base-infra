resource "aws_instance" "protoapp" {
  ami                    = "ami-051f8a213df8bc089"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_dmz.id]
  subnet_id              = aws_subnet.public_subnet_a.id

  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y httpd
                sudo systemctl enable httpd
                sudo systemctl start httpd
                echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "terraform-protoapp"
  }
}
