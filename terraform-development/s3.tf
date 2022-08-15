resource "aws_s3_bucket" "b" {
  bucket = "active-storage-tips-development-env"
}

output "bucket_domain_name" {
  value = aws_s3_bucket.b.bucket_domain_name
}
