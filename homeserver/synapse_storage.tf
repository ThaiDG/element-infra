resource "aws_s3_bucket" "synapse_storage" {
  bucket_prefix = "${var.workspace}-synapse-storage-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "synapse_storage_versioning" {
  bucket = aws_s3_bucket.synapse_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive_policy" {
  bucket = aws_s3_bucket.synapse_storage.id

  rule {
    id     = "archive-after-30-days"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
