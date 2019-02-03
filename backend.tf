terraform {
  backend "s3" {
    bucket = "7952-state-bucket"
    key    = "tf_state/rmstoys"
    region = "us-east-1"
  }
}
