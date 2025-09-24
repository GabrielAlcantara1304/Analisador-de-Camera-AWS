locals {
  name_prefix = "${var.project_name}"
}

# Kinesis Data Stream
resource "aws_kinesis_stream" "hand_stream" {
  name        = "${local.name_prefix}-stream"
  shard_count = var.kinesis_shard_count
}

# S3 Bucket para histórico
resource "aws_s3_bucket" "history" {
  bucket = "${local.name_prefix}-history-${random_id.bucket_rand.hex}"
}

resource "random_id" "bucket_rand" {
  byte_length = 4
}

# IAM Role para Firehose
resource "aws_iam_role" "firehose_role" {
  name               = "${local.name_prefix}-firehose-role"
  assume_role_policy = data.aws_iam_policy_document.firehose_trust.json
}

data "aws_iam_policy_document" "firehose_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

# Permissões Firehose -> S3 e leitura Kinesis
resource "aws_iam_role_policy" "firehose_policy" {
  name = "${local.name_prefix}-firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = data.aws_iam_policy_document.firehose_policy.json
}

data "aws_iam_policy_document" "firehose_policy" {
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      aws_s3_bucket.history.arn,
      "${aws_s3_bucket.history.arn}/*"
    ]
  }

  statement {
    sid    = "KinesisRead"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [aws_kinesis_stream.hand_stream.arn]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

# Firehose de Kinesis para S3
resource "aws_kinesis_firehose_delivery_stream" "to_s3" {
  name        = "${local.name_prefix}-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.hand_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.history.arn
    buffering_interval = 60
    buffering_size     = 5
    compression_format = "GZIP"
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${local.name_prefix}-firehose"
      log_stream_name = "S3Delivery"
    }
  }
}

# Lambda: pacote por archive_file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda.zip"
}

# IAM role para Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissão de leitura do Kinesis para Lambda (para o event source)
resource "aws_iam_role_policy" "lambda_kinesis_policy" {
  name = "${local.name_prefix}-lambda-kinesis"
  role = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_kinesis.json
}

data "aws_iam_policy_document" "lambda_kinesis" {
  statement {
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [aws_kinesis_stream.hand_stream.arn]
  }
}

# Função Lambda
resource "aws_lambda_function" "kinesis_processor" {
  function_name = "${local.name_prefix}-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout       = 10
  memory_size   = 256
}

# Trigger do Kinesis para Lambda
resource "aws_lambda_event_source_mapping" "kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.hand_stream.arn
  function_name     = aws_lambda_function.kinesis_processor.arn
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
}

# Usuário produtor opcional para rodar Python local
resource "aws_iam_user" "producer" {
  count = var.create_producer_user ? 1 : 0
  name  = "${local.name_prefix}-producer"
}

resource "aws_iam_access_key" "producer_key" {
  count = var.create_producer_user ? 1 : 0
  user  = aws_iam_user.producer[0].name
}

# Política mínima para produzir no stream
data "aws_iam_policy_document" "producer_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords",
      "kinesis:DescribeStream",
      "kinesis:ListShards"
    ]
    resources = [aws_kinesis_stream.hand_stream.arn]
  }
}

resource "aws_iam_user_policy" "producer_policy" {
  count  = var.create_producer_user ? 1 : 0
  name   = "${local.name_prefix}-producer-policy"
  user   = aws_iam_user.producer[0].name
  policy = data.aws_iam_policy_document.producer_policy_doc.json
}
