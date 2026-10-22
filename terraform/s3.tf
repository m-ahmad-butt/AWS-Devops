resource "aws_s3_bucket" "cv" {
  bucket = var.bucket_name

  tags = {
    Name = var.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "cv" {
  bucket = aws_s3_bucket.cv.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cv" {
  bucket = aws_s3_bucket.cv.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "site_files" {
  for_each = {
    "site/index.html" = {
      source       = "${path.module}/../site/index.html"
      content_type = "text/html"
    }
    "site/style.css" = {
      source       = "${path.module}/../site/style.css"
      content_type = "text/css"
    }
    "site/cv.pdf" = {
      source       = "${path.module}/../site/cv.pdf"
      content_type = "application/pdf"
    }
  }

  bucket       = aws_s3_bucket.cv.id
  key          = each.key
  source       = each.value.source
  content_type = each.value.content_type
  etag         = filemd5(each.value.source)

  depends_on = [
    aws_s3_bucket_public_access_block.cv,
    aws_s3_bucket_versioning.cv,
  ]
}
