# Data Quest

### This repo contains a POC example of creating and deplying with Terraform two Lambda functions, an SQS queue and other AWS event sourcing components.

### The execution flow is the following

A Lambda function scheduled to execute daily republishes to an S3 bucket [this open dataset from download.bls.gov](https://download.bls.gov/pub/time.series/pr/ of CSV files hosted on download.bls.gov and an an additonal JSON document republished to S3 from [this API from datausa.io](https://datausa.io/api/data?drilldowns=Nation&measures=Population).

Once the JSON file sourced from datausa.io is written to a S3 bucket, an S3 notification creates a message in a SQS queue.  For every message in this SQS queue a Lambda function is executed which reads the data from a S3 bucket the JSON file from datausa.io into a DatafRame as well as one CSV file from the set of files from download.bls.gov in which everal analysis functions are performed on the Data Frames.  A Jupyter Notebook file is included in the repo (data-quest.ipnyb) which has the same Pandas code.

The Terraform setup should be run with a role with the required priviliges setup with _aws configure_.  

The S3 bucket is assumed to be pre-existing and is not part of the Terraform configuration.  The bucket name can be changed in the ./terraform/vriables.tf file as well as the region and Python version.
