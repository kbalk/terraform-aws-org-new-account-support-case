
terraform {
  required_version = ">= 0.12"
}

locals {
  name = "new_account_support_case_${random_string.id.result}"
}

module "lambda" {
  source = "git::https://github.com/plus3it/terraform-aws-lambda.git?ref=v1.2.0"

  function_name = local.name
  description   = "Create new IAM Account Role"
  handler       = "new_account_support_case.lambda_handler"
  runtime       = "python3.8"
  source_path   = "${path.module}/lambda/src"
  timeout       = 300

  environment = {
    variables = {
      COMPANY_NAME = var.company_name
      CC_LIST      = var.cc_list
      LOG_LEVEL    = var.log_level
    }
  }
}

resource "random_string" "id" {
  length  = 13
  special = false
}

resource "aws_cloudwatch_event_rule" "this" {
  name          = local.name
  description   = "Managed by Terraform"
  event_pattern = <<-PATTERN
    {
      "source": ["aws.organizations"],
      "detail-type": ["AWS API Call via CloudTrail"],
      "detail": {
        "eventSource": ["organizations.amazonaws.com"],
        "eventName": [
            "InviteAccountToOrganization",
            "CreateAccount",
            "CreateGovCloudAccount"
        ]
      }
    }
    PATTERN
}

resource "aws_cloudwatch_event_target" "this" {
  rule = aws_cloudwatch_event_rule.this.name
  arn  = module.lambda.function_arn
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
