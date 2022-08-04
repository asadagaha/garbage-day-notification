variable "line_token" {
    type = string
}
variable "line_api_url" {
    type = string
}

module "lambda" {
  source                           = "../../module/lambda"
  dynamo_db_table_name             = module.dynamo_db.table_name
  line_token                       = var.line_token
  line_api_url                     = var.line_api_url
}

module "dynamo_db" {
  source                           = "../../module/dynamo_db"
}

module "cloudwatch_event" {
  source                           = "../../module/cloudwatch_event"
  lambda_arn                       = module.lambda.lambda_arn  
  function_name                    = module.lambda.function_name
}
