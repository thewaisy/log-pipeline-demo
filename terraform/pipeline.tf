
//kds
resource "aws_kinesis_stream" "kinesis_stream_to_s3" {
  name             = "kinesis-stream-to-s3"
  shard_count      = 1
  retention_period = 24

  lifecycle {
    ignore_changes = [shard_count]
  }
}

resource "aws_kinesis_stream" "kinesis_stream_to_es" {
  name             = "kinesis-stream-to-es"
  shard_count      = 1
  retention_period = 24
}

// kds error log event
resource "aws_kinesis_stream" "kinesis_stream_error_to_s3" {
  name             = "kinesis-stream-error-to-s3"
  shard_count      = 1
  retention_period = 24
}

//s3
resource "aws_s3_bucket" "log_bucket" {
  bucket = "log-bucket"
}

// es log group
// ES_APPLICATION_LOGS
resource "aws_cloudwatch_log_group" "cloudwatch_event_log_es_application_log_group" {
  name = "/aws/aes/domains/${aws_s3_bucket.log_bucket.id}/application-logs"
  retention_in_days = "1"
}
// INDEX_SLOW_LOGS
resource "aws_cloudwatch_log_group" "cloudwatch_event_log_es_index_slow_log_group" {
  name = "/aws/aes/domains/${aws_s3_bucket.log_bucket.id}/index-logs"
  retention_in_days = "1"
}
// SEARCH_SLOW_LOGS
resource "aws_cloudwatch_log_group" "cloudwatch_event_log_es_search_slow_log_group" {
  name = "/aws/aes/domains/${aws_s3_bucket.log_bucket.id}/search-logs"
  retention_in_days = "1"
}

resource "aws_cloudwatch_log_resource_policy" "cloudwatch_es_log_policy" {
  policy_name = "cloudwatch-es-event-log-policy"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}


//es
resource "aws_elasticsearch_domain" "log_es" {
  domain_name           = "log-es"
  elasticsearch_version = "7.4"

  cluster_config {
    instance_count = 1
    instance_type  = "t3.small.elasticsearch"

    dedicated_master_enabled = true
    dedicated_master_count   = 3
    dedicated_master_type    = "t3.small.elasticsearch"
    zone_awareness_enabled   = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp2"
  }

  snapshot_options {
    automated_snapshot_start_hour = 18
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  log_publishing_options {
    enabled = true
    log_type = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.cloudwatch_event_log_es_application_log_group.arn}:*"
  }
  log_publishing_options {
    enabled = true
    log_type = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.cloudwatch_event_log_es_index_slow_log_group.arn}:*"
  }
  log_publishing_options {
    enabled = true
    log_type = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.cloudwatch_event_log_es_search_slow_log_group.arn}:*"
  }

}

//es access policy
resource "aws_elasticsearch_domain_policy" "es_access_policy" {
  domain_name = aws_elasticsearch_domain.log_es.domain_name

  access_policies = <<POLICIES
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "${aws_elasticsearch_domain.log_es.arn}/*"
        }
    ]
}
POLICIES
}


//iam
resource "aws_iam_role" "firehose_to_s3_role" {
  name = "firehose-to-s3-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role" "firehose_to_es_role" {
  name = "firehose-to-es-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

// error log stream role
resource "aws_iam_role" "firehose_error_to_s3_role" {
  name = "firehose-error-to-s3-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}


//policy
resource "aws_iam_policy" "firehose_to_s3_policy" {
  name        = "firehose-to-s3-policy"
  description = "kinesis stream data to s3 via firehose policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
        "Effect": "Allow",
        "Action": [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
        ],
        "Resource": [
            "${aws_s3_bucket.log_bucket.arn}",
            "${aws_s3_bucket.log_bucket.arn}/*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.kinesis_stream_to_s3.arn}"

    }
  ]
}
EOF
}

resource "aws_iam_policy" "firehose_to_es_policy" {
  name        = "firehose-to-es-policy"
  description = "kinesis stream data to es via firehose policy"
  // https://docs.aws.amazon.com/ko_kr/firehose/latest/dev/controlling-access.html#using-iam-es-vpc
  // Amazon ES 도메인이 VPC에 있는 경우 EC2의 권한을 Kinesis Data Firehose에 부여
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:CreateNetworkInterfacePermission",
        "ec2:DeleteNetworkInterface"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
         "es:DescribeElasticsearchDomain",
         "es:DescribeElasticsearchDomains",
         "es:DescribeElasticsearchDomainConfig",
         "es:ESHttpPost",
         "es:ESHttpPut"
      ],
      "Resource": [
        "${aws_elasticsearch_domain.log_es.arn}",
        "${aws_elasticsearch_domain.log_es.arn}/*"
      ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
        ],
        "Resource": [
            "${aws_s3_bucket.log_bucket.arn}",
            "${aws_s3_bucket.log_bucket.arn}/*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.kinesis_stream_to_es.arn}"

    }
  ]
}
EOF
}

// error log stream policy
resource "aws_iam_policy" "firehose_error_to_s3_policy" {
  name        = "firehose-error-to-s3-policy"
  description = "kinesis stream data error log to s3 via firehose policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
        "Effect": "Allow",
        "Action": [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
        ],
        "Resource": [
            "${aws_s3_bucket.log_bucket.arn}",
            "${aws_s3_bucket.log_bucket.arn}/*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.kinesis_stream_error_to_s3.arn}"

    }
  ]
}
EOF
}

//policy attach
resource "aws_iam_role_policy_attachment" "s3_firehose_add_s3_policy" {
  policy_arn = aws_iam_policy.firehose_to_s3_policy.arn
  role       = aws_iam_role.firehose_to_s3_role.name
}

resource "aws_iam_role_policy_attachment" "es_firehose_add_es_policy" {
  policy_arn = aws_iam_policy.firehose_to_es_policy.arn
  role       = aws_iam_role.firehose_to_es_role.name
}

// error log stream policy attach
resource "aws_iam_role_policy_attachment" "error_firehose_add_s3_policy" {
  policy_arn = aws_iam_policy.firehose_to_s3_policy.arn
  role       = aws_iam_role.firehose_error_to_s3_role.name
}

//firehose
resource "aws_kinesis_firehose_delivery_stream" "firehose_to_s3" {
  name        = "firehose-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.kinesis_stream_to_s3.arn
    role_arn = aws_iam_role.firehose_to_s3_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_to_s3_role.arn
    bucket_arn = aws_s3_bucket.log_bucket.arn
    prefix = "event_log/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "error_log/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/error_type=!{firehose:error-output-type}/"
    buffer_size        = 25
    buffer_interval    = 300
  }
}

//firehose to es
resource "aws_kinesis_firehose_delivery_stream" "firehose_to_es" {
  name        = "firehose-to-es"
  destination = "elasticsearch"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_to_es_role.arn
    bucket_arn         = aws_s3_bucket.log_bucket.arn
    buffer_size        = 10
    buffer_interval    = 400
    compression_format = "GZIP"
  }

  elasticsearch_configuration {
    domain_arn = aws_elasticsearch_domain.log_es.arn
    role_arn   = aws_iam_role.firehose_to_es_role.arn
    index_name = "test"
    type_name  = "test"
  }

}

// error log firehose
resource "aws_kinesis_firehose_delivery_stream" "firehose_error_to_s3" {
  name        = "firehose-error-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.kinesis_stream_error_to_s3.arn
    role_arn = aws_iam_role.firehose_error_to_s3_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_error_to_s3_role.arn
    bucket_arn = aws_s3_bucket.log_bucket.arn
    prefix = "error_event_log/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "error_log/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/error_type=!{firehose:error-output-type}/"
    buffer_size        = 25
    buffer_interval    = 300
  }

  lifecycle {
    ignore_changes = [
      extended_s3_configuration
    ]
  }
}

