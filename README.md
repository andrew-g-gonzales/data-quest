# Data Quest

### This repo contains a POC example of creating and deploying with Terraform two Lambda functions, an SQS queue and other AWS event sourcing components.

### The execution flow is the following

A Lambda function scheduled to execute daily republishes to an S3 bucket [this open dataset from download.bls.gov](https://download.bls.gov/pub/time.series/pr/ of CSV files hosted on download.bls.gov and an additional  JSON document republished to S3 from [this API from datausa.io](https://datausa.io/api/data?drilldowns=Nation&measures=Population).

Once the JSON file sourced from datausa.io is written to a S3 bucket, an S3 notification creates a message in a SQS queue. For every message in this SQS queue a Lambda function is executed which reads the data from a S3 bucket the JSON file from datausa.io into a DatafRame as well as one CSV file from the set of files from download.bls.gov in which several analysis functions are performed on the Data Frames. A Jupyter Notebook file is included in the repo (data-quest.ipnyb) which has the same Pandas code.

The Terraform setup should be run with a role with the required priviliges setup with _aws configure_.  

The S3 bucket is assumed to be pre-existing and is not part of the Terraform configuration.  The bucket name can be changed in the ./terraform/vriables.tf file as well as the region and Python version.

_This project was developed on Ubuntu 24.04.1_


1. Lambda for sourcing data and republising to S3

     - _data-quest/code/source_lambda/source_lambda.py_ 

     - https://github.com/andrew-g-gonzales/data-quest/blob/main/code/source_lambda/source_lambda.py



2. Jupyter Notebook .ipynb file with Pandas analysis and report from data published by Lambda in step 1

    - _data-quest/data-quest.ipynb_

    - https://github.com/andrew-g-gonzales/data-quest/blob/main/data-quest.ipynb


3.  Lambda executing the same code from Jupyter Notebook in step #2.

    - _data-quest/code/report_lambda/report_lambda.py_ 
 
    - https://github.com/andrew-g-gonzales/data-quest/blob/main/code/report_lambda/report_lambda.py


4. Terraform code for the data pipeline infrastructure setup

    - _data-quest/terraform_ 

    - https://github.com/andrew-g-gonzales/data-quest/tree/main/terraform




