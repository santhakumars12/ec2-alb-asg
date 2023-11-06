provider "aws" {
  region = "ap-south-1"
}

data "aws_vpc" "default" {
  default = true
}

locals {
  user_data_script = file("${path.module}/user_data.sh")
}

resource "aws_security_group" "instance_sg" {
  name_prefix = "ec2-sg"
  description = "Example security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb_target_group" "ec2_tg" {
  name        = "ec2-instance-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "80"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb" "ec2_alb" {
  name               = "ec2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = ["subnet-086185918c6b100aa", "subnet-02cfd6e2eeaef5b95"]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ec2_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_tg.arn
  }
}



resource "aws_launch_template" "foo" {
  name = "ec2_launch_tempalte_for_asg"
  image_id = "ami-0f9d60d2a295ac3df"
  instance_type = "t2.micro"
  key_name = "webserver_keypair"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  network_interfaces {
    device_index = 0
    associate_public_ip_address = false  
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "test"
    }
  }

  user_data = base64encode(local.user_data_script)
}

resource "aws_autoscaling_group" "example_asg" {
  name             = "ec2-asg"
  max_size         = 4
  min_size         = 2
  desired_capacity = 3
  launch_template {
    id = aws_launch_template.foo.id
  }
  vpc_zone_identifier = ["subnet-086185918c6b100aa", "subnet-02cfd6e2eeaef5b95"]
  target_group_arns  = [aws_lb_target_group.ec2_tg.arn] 
  health_check_type  = "EC2"
}

