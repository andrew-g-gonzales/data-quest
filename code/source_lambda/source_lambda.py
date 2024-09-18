from lxml import html
import requests
from urllib.parse import urlparse
import boto3
import botocore
import hashlib
from requests.adapters import HTTPAdapter                  
from requests.packages.urllib3.util.retry import Retry
import json
import os


def get_md5(input_string):
    '''Provides MD5 of a given string.'''
    return hashlib.md5(input_string.encode()).hexdigest()

def file_name(fname, suffix=".csv"):
    '''Provides .csv suffix to list of files that do not have .txt suffix.'''
    return fname if '.txt' in fname else f'{fname}{suffix}'

def s3_md5sum(bucket_nm, resource_name):
    '''Provides MD5 of a given S3 object.'''
    md5sum = None
    try:
        md5sum = boto3.client('s3').head_object(
            Bucket=bucket_nm,
            Key=resource_name
        )['ETag'][1:-1]
    except botocore.exceptions.ClientError as e:
        print(f"Unexpected boto3 S3 access error: {e}")

    return md5sum

def delete_s3_obj(s3_c, bucket_nm, resource_name):
    '''Abstraction function for deleting an S3 object.'''
    try:
        s3_c.Object(bucket_nm, resource_name).delete()
    except botocore.exceptions.ClientError as e:
        print(f"Unexpected boto3 S3 delete error: {e}")


def put_s3_object(s3_c, bucket, file_nm, scontent):
    '''Abstraction function for writing/replacing an S3 object.'''
    try:
        s3_object = s3_c.Object(bucket, file_nm)
        s3_object.put(Body=scontent)
    except botocore.exceptions.ClientError as e:
        print(f"Unexpected boto3 S3 write error: {e}")

def exclude(full_list, excludes):
    '''Abstraction function excluding list elements that belong to a separate list.'''
    return [x for x in full_list if x[0] not in excludes]

def execute_request(url, session):
    '''Abstraction function for executing a HTTP request with a session object.'''
    response = None
    try:
        response = session.get(url)
        response.raise_for_status()
    except requests.exceptions.RequestException as err:
        print (err.response.text)
        raise err
    return response


def bls_gov_to_s3(bls_gov_url, bucket_name, session, s3):
    '''
    This is a function that does the following:
    1.) Parses the filenames in the html for https://download.bls.gov/pub/time.series/pr/
    2.) Compares files downloaded from download.bls.gov to obects in a specified S3 bucket.
        a.) If no files present, write all files
        b.) If a file was removed from download.bls.gov since last execution, delete it from S3
        c.) If a file was added to download.bls.gov since last execution, write it to S3
        d.) If a filename from download.bls.gov matches a file written to S3 from previous
            execution, compare MD5 sums of files, if not matching, then write file from 
            download.bls.gov to S3 to updates with the latest  
    '''
    parsed_uri = urlparse(bls_gov_url)
    protocol_host = '{uri.scheme}://{uri.netloc}/'.format(uri=parsed_uri)
    namespace = "/" + bls_gov_url.rpartition('/')[0].replace(protocol_host, '') + "/"

    response = execute_request(bls_gov_url, session)
    tree = html.fromstring(response.text)
    links = list(filter(lambda x: x[0] not in namespace,
                        [(fname, f'{protocol_host[:-1]}{fname}')
                         for fname in tree.xpath('//a/@href')]))

    #Getting a list of all S3 files in bucket excluding datausa.io JSON file
    existing_bucket_files = [file for file in s3.Bucket(bucket_name).objects.all() 
                             if '.json' not in file.key]
    
    #File writting to S3 have .csv as extension, this list appends the .csv extension 
    #for filename comparison
    file_names = [name.replace('.csv', '') for name, _ in links]

    #If files exist
    if existing_bucket_files:
        keys = [bfile.key.replace('.csv', '') for bfile in existing_bucket_files]
        print(keys)
        #Files to delete
        to_delete = [key for key in keys if key not in file_names]
        print("to delete:", to_delete)
        links_to_update = exclude(links, to_delete)
        #Files to add
        to_add = [file_nm for file_nm in file_names if file_nm not in keys]
        #Files to check  if changed on download.bls.gov
        links_to_update_2 = exclude(links_to_update, to_delete)
        print("to add:", to_add)
        print("to check for updates:", links_to_update_2)
        for name, link in links_to_update_2:
            file_nm = file_name(name)
            print(file_nm)
            put_file = False
            if name in to_add:
                print('adding new file:', name)
                put_file = True
            try:
                with session.get(link, timeout=30, stream=True) as r:
                    r.raise_for_status()
                    if not put_file:
                        nfile_md5 = get_md5(r.text).strip()
                        s3_md5 = s3_md5sum(bucket_name, file_nm).strip()
                        if nfile_md5 != s3_md5:
                            print("not matching: " + nfile_md5 + ", " + s3_md5)
                            put_file = True
                    if put_file:
                        print('put for object:', file_nm)
                        put_s3_object(s3, bucket_name, file_nm, r.content)
            except Exception as err:
                print (f"Exception occured in MD5 S3/bls file comparison {err=}")
                raise err

        if to_delete:
            for key in to_delete:
                delete_s3_obj(s3, bucket_name, file_name(key))
    #If files do not exist
    else:
        for name, link in links:
            with session.get(link, timeout=30, stream=True) as r:
                print("writing to s3:", link)
                put_s3_object(s3, bucket_name, file_name(name), r.content)

def datausa_tos3(datausa_url, bucket_name, session, s3):
    '''
    Function to download file from datausa.io URL and write to S3
    '''
    response = execute_request(datausa_url, session)
    data = response.json()['data']

    payload = json.dumps(data)
    print(payload)
    put_s3_object(s3, bucket_name, "datausa.json", payload)


def main(event, context):
    '''
    Lambda execution function
    '''

    bucket_name = os.environ['BUCKET']
    bls_gov_url = os.environ['BLS_GOV_URL']
    datausa_url = os.environ['DATAUSA_URL']

    headers =  {
        'User-agent': 'Agent/1.0 (https://stmarkssolutions.com)'
          }

    #Retry strategy to be used by session for all requests
    retry_strategy = Retry(           
        total=3,                        
        backoff_factor=1              
     )                              
                                  
    adapter = HTTPAdapter(max_retries=retry_strategy)
    #Using a session object as not to create many request objects  
    session = requests.Session() 
    session.headers.update(headers)  
    session.mount("https://", adapter)
    session.mount("http://", adapter)

    # Creating reusable S3 object
    s3 = boto3.resource('s3')

    bls_gov_to_s3(bls_gov_url, bucket_name, session, s3)
    datausa_tos3(datausa_url, bucket_name, session, s3)

