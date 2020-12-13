# conf the AWS Provider
provider "aws" {
    region = var.availability_zone_names[0] # zone
    access_key = var.access_key_var
    secret_key = var.secret_key_var
}

# 1. vpc
resource "aws_vpc" "test" {
  cidr_block = var.vpc_ip
}

# 2. Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test.id
}

# 3. Route Table
resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "test"
  }
}

# 4. Subnet 

resource "aws_subnet" "test-subnet" {
  vpc_id            = aws_vpc.test.id
  cidr_block        = var.subnets_names[0] 
  availability_zone = var.availability_zone_names[1]
  tags = {
    Name = "test-subnet"
  }
}


resource "aws_subnet" "test2-subnet" {
  vpc_id            = aws_vpc.test.id
  cidr_block        = var.subnets_names[1]
  availability_zone = var.availability_zone_names[2]
  tags = {
    Name = "test-subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.test-subnet.id
  route_table_id = aws_route_table.test-route-table.id
}

# 6. Create Security Group to allow port 22,80,443,5000
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "HTTPS"
    from_port   = 443  # 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "docker"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# # 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.test-subnet.id
  private_ips     = var.privte_ip
  security_groups = [aws_security_group.allow_web.id]
}



# # 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = var.privte_ip[0]
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami               = var.image_id     # "ami-0502e817a62226e03"
  instance_type     = "t2.micro"
  availability_zone = var.availability_zone_names[1]
  key_name          = "gazal"


  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  # commands that run when the Ubuntu server is creating
  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install docker.io -y
                chown ubuntu home/ubuntu
                EOF

  tags = {
    Name = "web-server"
  }
  
  # copy file from my os to the Ubuntu server
  provisioner "file" {
    source      = "C:/Users/PC/Desktop/terraform/flask" #the file to copy
    destination = "/home/ubuntu" # where to copy

    # make connection to the Ubuntu server
    connection {
    type     = "ssh"
    private_key = "${file("C:/Users/PC/Desktop/terraform/gazal.pem")}" # privte key
    user     = "ubuntu"
    host     = aws_instance.web-server-instance.public_ip #public ip to the Ubuntu server
    agent = false
    }
  }

  # commands to run after creating the Ubuntu server
  provisioner "remote-exec" {
    # commands to build the python image and run it
    inline = [
      "cd flask", 
      "sudo apt update -y",
      "sudo apt install docker.io -y",
      "sudo docker build -t bitcoin .",
      "sudo docker run -d -p 5000:5000 bitcoin"
    ]

    # make connection to the Ubuntu server
    connection {
    type     = "ssh"
    private_key = "${file("C:/Users/PC/Desktop/terraform/gazal.pem")}" # privte key
    user     = "ubuntu"
    host     = aws_instance.web-server-instance.public_ip #public ip to the Ubuntu server
    agent = false
    }
  }
  
}

# # Create a new load balancer
resource "aws_lb" "testlb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.test-subnet.id, aws_subnet.test2-subnet.id]

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

# creat a aws target group
resource "aws_lb_target_group" "testgr" {
  name     = "target"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.test.id
}

# connect the aold balncer to the target group 
resource "aws_lb_target_group_attachment" "con" {
  target_group_arn = aws_lb_target_group.testgr.arn
  target_id        = aws_instance.web-server-instance.id
  port             = 5000
}



 
