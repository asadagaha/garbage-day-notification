variable "line_token" {
    type = string
}

module "lambda" {
  source                           = "../../module/lambda"
  dynamo_db_table_name             = module.dynamo_db.table_name
  line_token                = var.line_token
}

module "dynamo_db" {
  source                           = "../../module/dynamo_db"
}

module "cloudwatch_event" {
  source                           = "../../module/cloudwatch_event"
  lambda_arn                       = module.lambda.lambda_arn  
  function_name                    = module.lambda.function_name
}
