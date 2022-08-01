resource "aws_dynamodb_table" "trash-day-table" {
  name           = "garbage-day-table"
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
