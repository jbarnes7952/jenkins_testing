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
  supported_identity_providers = [ "COGNITO", "${aws_cognito_identity_provider.rmstoys_provider_google.provider_type}", "${aws_cognito_identity_provider.rmstoys_provider.provider_type}" ] 
	allowed_oauth_flows          = ["code", "implicit"]
  allowed_oauth_scopes         = ["phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"]  
  allowed_oauth_flows_user_pool_client = true
	callback_urls                = ["https://www.rmstoys.com"]
  user_pool_id = "${aws_cognito_user_pool.rmstoys.id}"
}


resource "aws_cognito_identity_provider" "rmstoys_provider_google" {
  user_pool_id  = "${aws_cognito_user_pool.rmstoys.id}"
  provider_name = "Google"
  provider_type = "Google"

  provider_details {
		attributes_url   = "https://api.amazon.com/user/profile"
		authorize_url    = "https://www.amazon.com/ap/oa"
		attributes_url_add_attributes = "false" 
		token_url        = "https://api.amazon.com/auth/o2/token"
		token_request_method = "POST"
    authorize_scopes = "email"
    client_id        = "414426311691-20dmmc2i695aut3736sai2t610sjva8a.apps.googleusercontent.com"
    client_secret    = "hna7tp6EXhsl72HyAbj71WF-"
  }

	attribute_mapping {
		email = "email"
		username = "sub"
	}


}

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
