output "kinesis_stream_name" {
  value = aws_kinesis_stream.hand_stream.name
}

output "firehose_name" {
  value = aws_kinesis_firehose_delivery_stream.to_s3.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.history.id
}

output "lambda_function_name" {
  value = aws_lambda_function.kinesis_processor.function_name
}

output "producer_access_key_id" {
  value     = try(aws_iam_access_key.producer_key[0].id, null)
  sensitive = true
}

output "producer_secret_access_key" {
  value     = try(aws_iam_access_key.producer_key[0].secret, null)
  sensitive = true
}
