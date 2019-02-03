provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "nobody@rmstoys.com"
}

resource "acme_certificate" "certificate" {
  account_key_pem = "${acme_registration.reg.account_key_pem}"
  common_name     = "test.rmstoys.com"

  #subject_alternative_names = ["www2.example.com"]

  dns_challenge {
    provider = "route53"
  }
}

resource "aws_iam_server_certificate" "elb_cert" {
  name_prefix       = "rmstoys-cert-"
  certificate_body  = "${acme_certificate.certificate.certificate_pem}"
  certificate_chain = "${acme_certificate.certificate.issuer_pem}"
  private_key       = "${acme_certificate.certificate.private_key_pem}"

  lifecycle {
    create_before_destroy = true
  }
}

output "aws_iam_server_certificate_elb_cert_arn" {
	value = "${aws_iam_server_certificate.elb_cert.arn}"
}
