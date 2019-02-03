variable count {

}
variable key_name {

}

variable vpc_security_group_ids {
  type = "list"
}


variable private_key_pem {

}

variable "aws_subnet_public_1_id" {
	
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["packer-example*"] }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"] # Canonical
}

resource "aws_instance" "nginx" {
  count = "${var.count}"

  connection {
    # The default username for our AMI, and use our on the fly created 
    # private key to do the initial bootstrapping (install of nginx)
    user = "ubuntu"

    private_key = "${var.private_key_pem}"
  }

  instance_type          = "t2.micro"
  # ami                    = "ami-0e996bcfc16fdf6d5"
	ami                    = "${data.aws_ami.ubuntu.id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]

  # We're going to launch into the same single (public) subnet as our ELB. 
  # In a production environment it's more common to have a separate 
  # private subnet for backend instances.
  subnet_id = "${var.aws_subnet_public_1_id}"

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80

	#   provisioner "remote-exec" {
	#     inline = [
	#       "sudo apt-get -y update",
	#       "sudo apt-get -y install nginx",
	#       "sudo sed -i 's/nginx\\!/nginx - instance ${count.index + 1}/g' /var/www/html/index.nginx-debian.html",
	#       "sudo systemctl start nginx",
	#     ]
	#   }

  # provisioner "remote-exec" 
  #   inline = [
  #     "sudo apt-get -y update",
  #     "sudo apt-get -y install python3",
  #     "git clone https://github.com/aws/amazon-cognito-auth-js.git",
	# 	  "cd amazon-cognito-auth-js/sample && ln -s ../dist/ dist"	
  #   ]
  # }


  tags {
    Name    = "rmstoys-nginx${count.index + 1}"
    Purpose = "rmstoys"
  }
}

output "aws_instance_nginx_id" {
	value = "${aws_instance.nginx.id}"
}
