resource "aws_iam_role" "ec2" {
  name               = "cv-ec2-role-${var.roll_lower}"
  assume_role_policy = file("${path.module}/../iam/ec2-trust-policy.json")

  tags = {
    Name = "cv-ec2-role-${var.roll_lower}"
  }
}

resource "aws_iam_role_policy" "ec2" {
  name   = "cv-ec2-s3-policy"
  role   = aws_iam_role.ec2.id
  policy = file("${path.module}/../iam/ec2-permission-policy.json")
}

resource "aws_iam_instance_profile" "ec2" {
  name = "cv-ec2-profile-${var.roll_lower}"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role" "lambda" {
  name               = "cv-lambda-role-${var.roll_lower}"
  assume_role_policy = file("${path.module}/../iam/lambda-trust-policy.json")

  tags = {
    Name = "cv-lambda-role-${var.roll_lower}"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name   = "cv-lambda-s3-policy"
  role   = aws_iam_role.lambda.id
  policy = file("${path.module}/../iam/lambda-permission-policy.json")
}
