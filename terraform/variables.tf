variable "region" {
    type = string
    default = "us-east-1"
}

variable "source_lambda_name" {
    default = "data-quest-source-lambda"
    type = string
    description = "Name of Lambda that runs daily to fetch CSV files from download.bls.gov and a JSON file from datausa.io and writes files to S3"
}

variable "report_lambda_name" {
    type = string
    default = "data-quest-report-lambda"
    description = "Name of Lambda triggered by SQS message generated when JSON file from datausa.io is written to S3. The Lambda execution parses the JSON file and one download.bls.gov CVS file from S3 and performs analysis.  "
}

variable "python_version" {
    default = "python3.9"
    type = string
    description = "Python version used for Lambda runtime and generating layer"
}

variable "data_quest_bucket_arn" {
    default = "arn:aws:s3:::data-quest-1"
    type = string
    description = "S3 bucket ARN where CSV and JSON files are written to"
}

variable "data_quest_bucket_name" {
    default = "data-quest-1"
    type = string
    description = "Name of S3 bucket ARN where CSV and JJSON files are written to"
}

variable "bls_gov_url" {
    default = "https://download.bls.gov/pub/time.series/pr"
    type = string
    description = "URL where CSV files are downloaded from by the Lambda function 'data-quest-source-lambda'"
}

variable "datausa_url" {
    default = "https://datausa.io/api/data?drilldowns=Nation&measures=Population"
    type = string
    description = "URL where one JSON file is downloaded from by the Lambda function 'data-quest-source-lambda'"
}

variable "s3_bls_gov_current_file" {
    default = "s3://data-quest-1//pub/time.series/pr/pr.data.0.Current.csv"
    type = string
    description = "CSV file in S3 sourced from download.bls.gov which is parsed and executed for analysis by Pandas in the Lambda function 'data-quest-report-lambda'"
}

variable "s3_datausa_file" {
    default = "s3://data-quest-1/datausa.json"
    type = string
    description = "JSON file in S3 sourced from datausa.io which is parsed and executed for analysis by Pandas in the Lambda function 'data-quest-report-lambda'"
}