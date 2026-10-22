data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/cv-func-${var.roll_lower}"
  retention_in_days = 7
}

resource "aws_lambda_function" "cv" {
  function_name = "cv-func-${var.roll_lower}"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handler"
  runtime       = "python3.13"
  architectures = ["x86_64"]
  memory_size   = 128
  timeout       = 10

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      BUCKET = aws_s3_bucket.cv.bucket
      PREFIX = "site"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_s3,
    aws_s3_object.site_files,
  ]

  tags = {
    Name = "cv-func-${var.roll_lower}"
  }
}

resource "aws_lambda_function_url" "cv" {
  function_name      = aws_lambda_function.cv.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "function_url" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.cv.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# Required in this account for AuthType NONE URLs (InvokeFunctionUrl alone returned 403)
resource "aws_lambda_permission" "function_url_invoke" {
  statement_id  = "FunctionURLAllowInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cv.function_name
  principal     = "*"
}
