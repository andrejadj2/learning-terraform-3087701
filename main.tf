data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0.1"  # Ažurirana verzija

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.17.0"

  name               = "blog-alb"
  load_balancer_type = "application"
  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = [module.blog_sg.security_group_id]

  # Simplified listener configuration
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "blog_tg"
      }
    }
  }

  # Simplified target group configuration
  target_groups = {
    blog_tg = {
      create_attachment = false  # We'll attach through ASG
      name_prefix       = "blog-"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      
      # Health check settings
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}

module "blog_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0.0"

  name = "blog"

  min_size            = 1
  max_size            = 2
  vpc_zone_identifier = module.blog_vpc.public_subnets
  
  # Launch template configuration
  launch_template_name        = "blog-lt"
  launch_template_description = "Launch template for blog application"
  update_default_version      = true
  
  # Instance configuration
  image_id        = data.aws_ami.app_ami.id
  instance_type   = var.instance_type
  security_groups = [module.blog_sg.security_group_id]
  
  # Attach target group
  traffic_source_attachments = {
    blog_tg = {
      traffic_source_identifier = module.blog_alb.target_groups["blog_tg"].arn
      traffic_source_type       = "elbv2"
    }
  }

  # Health check configuration
  health_check_type         = "ELB"
  health_check_grace_period = 300
  
  # Tags
  tag_specifications = [
    {
      resource_type = "instance"
      tags = {
        Name = "blog-instance"
      }
    }
  ]
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3.0"  # Ažurirana verzija

  vpc_id  = module.blog_vpc.vpc_id
  name    = "blog"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}