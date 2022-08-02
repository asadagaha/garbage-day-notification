resource "aws_dynamodb_table" "garbage_day_table" {
  name           = "garbage_day_table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "date"
 
  attribute {
    name = "date"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

}
