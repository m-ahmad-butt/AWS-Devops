output "bucket_name" {
  value = aws_s3_bucket.cv.bucket
}

output "ec2_public_ip" {
  value = aws_instance.cv.public_ip
}

output "ec2_url" {
  value = "http://${aws_instance.cv.public_ip}/"
}

output "ec2_instance_id" {
  value = aws_instance.cv.id
}

output "lambda_function_name" {
  value = aws_lambda_function.cv.function_name
}

output "lambda_url" {
  value = aws_lambda_function_url.cv.function_url
}

output "security_group_id" {
  value = aws_security_group.cv.id
}
