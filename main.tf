module "acme" {
	source = "modules/acme"
}

module "compute" {
	source = "modules/compute"
	count = "${var.demo_env_nginx_count}" 
	key_name = "${aws_key_pair.nginx-provisioning.id}"
	private_key_pem = "${tls_private_key.nginx-provisioner.private_key_pem}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
	aws_subnet_public_1_id = "${aws_subnet.public_1.id}"
}

data "aws_route53_zone" "primary" {
  name = "rmstoys.com."
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "test.rmstoys.com"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_lb.web.dns_name}"]
}

resource "aws_route53_record" "main" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "rmstoys.com"
  type    = "A"

  alias {
    name                   = "${aws_lb.web.dns_name}"
    zone_id                = "${aws_lb.web.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_vpc" "rmstoys" {
  cidr_block           = "10.20.100.0/24"
  enable_dns_hostnames = true

  tags {
    Name    = "rmstoys-vpc"
    Purpose = "rmstoys"
  }
}

# Internet gateway gives subnet access to the internet
resource "aws_internet_gateway" "rmstoys-ig" {
  vpc_id = "${aws_vpc.rmstoys.id}"

  tags {
    Name    = "rmstoys-ig"
    Purpose = "rmstoys"
  }
}

# Ensure VPC can access internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.rmstoys.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.rmstoys-ig.id}"
}

# Create a subnet for our instances 
resource "aws_subnet" "public_1" {
  vpc_id                  = "${aws_vpc.rmstoys.id}"
  cidr_block              = "10.20.100.32/27"
  map_public_ip_on_launch = true

  availability_zone = "us-east-1a"

  tags {
    Name    = "rmstoys-subnet"
    Purpose = "rmstoys"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = "${aws_vpc.rmstoys.id}"
  cidr_block              = "10.20.100.64/27"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1f"

  tags {
    Name    = "rmstoys-subnet"
    Purpose = "rmstoys"
  }
}

# ALB security group (ensure its accessible via the web)
resource "aws_security_group" "elb" {
  name        = "rmstoys-sg-elb"
  description = "ELB security group"
  vpc_id      = "${aws_vpc.rmstoys.id}"

  # # HTTPS access from anywhere
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }


  # # outbound internet access
  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags {
    Name    = "rmstoys-sg-elb"
    Purpose = "rmstoys"
  }
}

resource "aws_security_group_rule" "allow_all_in" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.elb.id}"
}

resource "aws_security_group_rule" "allow_80_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.elb.id}"
}

resource "aws_security_group_rule" "allow_all_out" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.elb.id}"
}


resource "aws_lb" "web" {
  name               = "rmstoys-elb-www"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${aws_subnet.public_1.id}", "${aws_subnet.public_2.id}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  # enable_deletion_protection = true


  # access_logs {
  #   bucket  = "${aws_s3_bucket.lb_logs.bucket}"
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags {
    Name    = "rmstoys-elb"
    Purpose = "rmstoys"
  }
}

resource "aws_lb_target_group" "front_end" {
  name     = "rmstoys-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.rmstoys.id}"
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = "${aws_lb_target_group.front_end.arn}"
  target_id        = "${module.compute.aws_instance_nginx_id}"
  port             = 80
}

resource "aws_lb_listener" "redirect" {
  load_balancer_arn = "${aws_lb.web.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }

    target_group_arn = "${aws_lb_target_group.front_end.arn}"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.web.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${module.acme.aws_iam_server_certificate_elb_cert_arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.front_end.arn}"
  }
}

# resource "aws_elb" "web" {
#   name = "rmstoys-elb-www"
#   
#   subnets         = ["${aws_subnet.public.id}"]
#   security_groups = ["${aws_security_group.elb.id}"]
#   instances       = ["${aws_instance.nginx.*.id}"]
# 
#   listener {
#     instance_port      = 80
#     instance_protocol  = "http"
#     lb_port            = 443
#     lb_protocol        = "https"
#     ssl_certificate_id = "${aws_iam_server_certificate.elb_cert.arn}"
# 
#   }
# 
#   tags {
#     Name    = "rmstoys-elb"
#     Purpose = "rmstoys"
#   }
# }

# ------------------------------------------
#  AWS : Instance (nginx) related config
# ------------------------------------------

# Our Nginx security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "nginx-sg" {
  name        = "rmstoys-nginx-sg"
  description = "Security group for nginx"
  vpc_id      = "${aws_vpc.rmstoys.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.20.100.0/24"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name    = "rmstoys-nginx-sg"
    Purpose = "rmstoys"
  }
}

# ----------------------------------------------------
# Terraform currently only supports importing an existing 
# key pair, not creating a new key pair
# ----------------------------------------------------
resource "tls_private_key" "nginx-provisioner" {
  algorithm = "RSA"
}

resource "aws_key_pair" "nginx-provisioning" {
  key_name   = "rmstoys-provisioning-key"
  public_key = "${tls_private_key.nginx-provisioner.public_key_openssh}"
}

resource "aws_cognito_user_pool" "rmstoys" {
  name = "rmstoys"
	alias_attributes = ["email", "phone_number"]
  # username_attributes = ["email", "phone_number"]

	auto_verified_attributes = ["email"]

# 	schema {
# 		attribute_data_type = "String"
# 		mutable = "true"
# 		required = "true"
# 		name = "profile"
# 		string_attribute_constraints = {
# 			max_length = 2048
# 			min_length = 0
# 		}
# 	}


	schema {
		attribute_data_type = "String"
		mutable = "true"
		required = "true"
		name = "email"
		string_attribute_constraints = {
			max_length = 2048
			min_length = 0
		}
	}
}

resource "aws_cognito_user_pool_client" "client" {
  name = "rmstoys_app_client"
  supported_identity_providers = [ "COGNITO", "${aws_cognito_identity_provider.rmstoys_provider.provider_type}" ] 
  # supported_identity_providers = [ "COGNITO", "${aws_cognito_identity_provider.rmstoys_provider_google.provider_type}", "${aws_cognito_identity_provider.rmstoys_provider.provider_type}" ] 
	allowed_oauth_flows          = ["code", "implicit"]
  allowed_oauth_scopes         = ["phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"]  
  allowed_oauth_flows_user_pool_client = true
	callback_urls                = ["https://www.rmstoys.com"]
  user_pool_id = "${aws_cognito_user_pool.rmstoys.id}"
}

# resource "aws_cognito_identity_provider" "rmstoys_provider_google" {
#   user_pool_id  = "${aws_cognito_user_pool.rmstoys.id}"
#   provider_name = "Google"
#   provider_type = "Google"
# 
#   provider_details {
# 		attributes_url   = "https://api.amazon.com/user/profile"
# 		authorize_url    = "https://www.amazon.com/ap/oa"
# 		attributes_url_add_attributes = "false" 
# 		token_url        = "https://api.amazon.com/auth/o2/token"
# 		token_request_method = "POST"
#     authorize_scopes = "email"
#     client_id        = "414426311691-20dmmc2i695aut3736sai2t610sjva8a.apps.googleusercontent.com"
#     client_secret    = "hna7tp6EXhsl72HyAbj71WF-"
#   }
# 
# 	attribute_mapping {
# 		email = "email"
# 		username = "sub"
# 	}
# }

resource "aws_cognito_identity_provider" "rmstoys_provider" {
  user_pool_id  = "${aws_cognito_user_pool.rmstoys.id}"
  provider_name = "LoginWithAmazon"
  provider_type = "LoginWithAmazon"

  provider_details {
		attributes_url   = "https://api.amazon.com/user/profile"
		authorize_url    = "https://www.amazon.com/ap/oa"
		attributes_url_add_attributes = "false" 
		token_url        = "https://api.amazon.com/auth/o2/token"
		token_request_method = "POST"
    authorize_scopes = "profile postal_code"
    client_id        = "amzn1.application-oa2-client.d9f7c4ec5adc4ed681aa7ee329278aa8"
    client_secret    = "68b6f34fa336fda8627e10420c1ebeae677312e94a0b8ac26b2ba57b14e4d87e"
  }

	attribute_mapping {
		email = "email"
		username = "user_id"
	}

}
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "rmstoys"
  user_pool_id = "${aws_cognito_user_pool.rmstoys.id}"
}

output "login_url" {
	value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.us-east-1.amazoncognito.com/login?response_type=code&client_id=${aws_cognito_user_pool_client.client.id}&redirect_uri=${aws_cognito_user_pool_client.client.callback_urls[0]}"
}
