data "archive_file" "ebs-backup-py" {
    type        = "zip"
    source_file = "${path.module}/ebs-backup.py"
    output_path = "${path.module}/ebs-backup.zip"
}

resource "aws_iam_role" "lambda_ebs_backup" {
    name = "lambda_ebs_backup"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_ebs_backup_policy" {
    name = "lambda_ebs_backup_policy"
    role = "${aws_iam_role.lambda_ebs_backup.id}"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:DeleteSnapshot",
                "ec2:DescribeInstances",
                "ec2:DescribeSnapshots",
                "ec2:DescribeRegions"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_lambda_function" "lambda_ebs_backup" {
    filename = "${path.module}/ebs-backup.zip"
    function_name = "ebs-backup"
    role = "${aws_iam_role.lambda_ebs_backup.arn}"
    handler = "ebs-backup.lambda_handler"
    source_code_hash = "${data.archive_file.ebs-backup-py.output_base64sha256}"
    runtime = "python3.6"
    timeout = 60
}

resource "aws_cloudwatch_event_rule" "lambda_ebs_backup" {
    name = "lambda_ebs_backup"
    description = "Run backups once a day"
    schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_ebs_backup" {
    rule = "${aws_cloudwatch_event_rule.lambda_ebs_backup.name}"
    target_id = "ebs-backup"
    arn = "${aws_lambda_function.lambda_ebs_backup.arn}"
}

resource "aws_lambda_permission" "lambda_ebs_backup" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.lambda_ebs_backup.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.lambda_ebs_backup.arn}"
}
