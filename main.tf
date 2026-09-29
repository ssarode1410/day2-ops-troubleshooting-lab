# 1. Provider Configuration (Pointing to local Floci emulator)
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  
  # Bypass standard AWS checks since we are running locally
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Route AWS services to the Floci Docker container on WSL
  endpoints {
    sqs    = "http://localhost:4566"
    lambda = "http://localhost:4566"
    iam    = "http://localhost:4566"
  }
}

# 2. The SQS Queue (The trigger)
resource "aws_sqs_queue" "order_queue" {
  name = "day2-lab-order-queue"
}

# 3. IAM Role for Lambda (The Permissions)
resource "aws_iam_role" "lambda_exec_role" {
  name = "day2_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 4. IAM Policy Attachment (Allowing Lambda to read from SQS)
resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# 5. The Lambda Function (The Compute)
resource "aws_lambda_function" "order_processor" {
  function_name = "day2-order-processor"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "main.handler"
  runtime       = "python3.9"

  # We will create this zip file in the next step
  filename      = "lambda_function.zip"
  
  # Ensure the role is created before the function
  depends_on = [aws_iam_role_policy_attachment.lambda_sqs_policy]
}

# 6. Event Source Mapping (Connecting the Queue to the Lambda)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.order_queue.arn
  function_name    = aws_lambda_function.order_processor.arn
  batch_size       = 1
}