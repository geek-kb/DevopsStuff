#!/usr/bin/env python3
# Written by Itai Ganot 2018
"""This script can:
1. List all AWS SSM parameters and their values in a given KMS id
(staging / production / integration)
Example:
./ssm_manage.py -r us-east-1 -e staging
2. Go through a file and get the values for all included keys
Example:
./ssm_manage.py -r us-east-1 -f some_creds.txt
3. Return a specific key per a given value
Example:
./ssm_manage.py -r us-east-1 -v some_keys_value
4. Replace single / multiple parameters with a given value
Example:
./ssm_manage.py -k cred_test_itai -r us-east-1 -p aaa
5. Save the results to file or print to screen
Example:
./ssm_manage.py -r us-east-1 -e production -w output-file
6. Count the number of parameters per given environment
Example:
./ssm_manage.py -r us-east-1 -e production -c
"""

import boto3
import argparse
import sys
import os
from subprocess import Popen, PIPE
from botocore.exceptions import ClientError


def count_params_per_env(env):
    final_keyid = 'alias/param_key_{}'.format(env)
    command = 'aws ssm describe-parameters | \
        jq -r \'.Parameters[] | ' \
        'select(.KeyId=="{}") | \
        .Name\' | wc -l'.format(final_keyid)
    proc = Popen(command, shell=True, stdout=PIPE, encoding='utf8')
    output = proc.communicate()[0]
    print('Number of params in environment {}: {}'.format(
        env,
        output.strip()
    ),end="")
    sys.exit()


def get_all_params_names(ssmclient, env, write_out):
    final_keyid = 'alias/param_key_{}'.format(env)
    print('Working on env: {}'.format(env))
    marker = None
    count = 0
    paginator = ssmclient.get_paginator('describe_parameters')
    page_iterator = paginator.paginate(Filters=
    [{
        'Key': 'KeyId',
        'Values': [final_keyid]
    }],
        PaginationConfig={
            'PageSize': 10,
            'NextToken': marker
        })

    for page in page_iterator:
        if not page['Parameters']:
            break
        else:
            for param in page['Parameters']:
                count += 1
                param_value = ssmclient.get_parameter(
                    Name=param['Name'],
                    WithDecryption=True)['Parameter']['Value']
                message = '#{} Name: {} | Value: {} | KeyId: {}'.format(
                    count,
                    param['Name'],
                    param_value,
                    final_keyid)
                if write_out != None:
                    with open(write_out, 'w+') as f:
                        f.write(message + '\n')
                else:
                    print(message)
    print('Finished processing {} parameters in KMS {}'.format(
        count,
        final_keyid))


def replace_parameter_value(ssmclient, key, put_value):
    try:
        ssmclient.put_parameter(Name=key,
                                Value=put_value,
                                Type='SecureString',
                                Overwrite=True)
    except Exception as e:
        print(e)
    else:
        print('Key {} successfully updated!'.format(key.strip()))


def get_key_of_value(ssmclient, value, write_out):
    marker = None
    count = 0
    param_keys = []
    paginator = ssmclient.get_paginator('describe_parameters')
    page_iterator = paginator.paginate(PaginationConfig={
        'PageSize': 10,
        'NextToken': marker
    })
    for page in page_iterator:
        if not page['Parameters']:
            break
        else:
            for param in page['Parameters']:
                count += 1
                param_name = param['Name']
                message = '#{} Now processing parameter: {}'.format(
                    count,
                    param_name)
                if write_out != None:
                   write_out_to_file(write_out, message)
                else:
                    print(message)
                    param_value = ssmclient.get_parameter(Name=param_name,
                                            WithDecryption=True)['Parameter']
                    if param_value['Value'] == value:
                        param_keys.extend(param_value['Name'])
                        print('Value {} found in parameter {}'.format(
                            value,
                            param_name))


def get_specific_param_value(ssmclient, search_value):
    try:
        specific_param_value = ssmclient.get_parameter(
            Name=search_value,
            WithDecryption=True)['Parameter']
        message = "Name: {} | Value: {} ".format(
            search_value,
            specific_param_value['Value'])
        print(message)
        return specific_param_value
    except Exception as e:
        print('No such parameter found: {}, Error: {}'.format(
            search_value,
            e))


def load_file(params_list):
    with open(params_list, 'r', encoding='ascii') as f:
        return f.readlines()


def create_resource_instance(region):
    ssmclient = boto3.client('ssm', region_name=region)
    return ssmclient


def write_out_to_file(write_out, text):
    if write_out != None:
        is_file = os.path.isfile('{}'.format(write_out))
        if is_file:
            try:
                with open(write_out, 'a+') as f:
                    f.writelines(text + '\n')
            except Exception as e:
                print(e)
        else:
            try:
                with open(write_out, 'x') as f:
                    f.writelines(text + '\n')
            except Exception as e:
                print(e)


def main(env,
         key,
         parameters_file,
         region,
         put_value,
         value,
         output_file,
         count_params):
    ssmc = create_resource_instance(region)
    if count_params and env != '':
        count_params_per_env(env)
    if env and output_file:
        get_key_of_value(ssmc, value, output_file)
    if parameters_file:
        try:
            a = load_file(parameters_file)
            for param in a:
                get_specific_param_value(ssmc, param.strip())
        except FileNotFoundError as e:
            e = str(e)
            print(e[10:])
    if value and output_file:
        get_key_of_value(ssmc, value, output_file)
    if value:
        get_key_of_value(ssmc, value, output_file)
    if env:
        try:
            get_all_params_names(ssmc, env, output_file)
        except ClientError as e:
            if e.response['Error']['Code'] == 'UnrecognizedClientException':
                print('No Access Key configured!')
    if put_value and key:
        replace_parameter_value(ssmc, key, put_value)
    if put_value and parameters_file:
        a = load_file(parameters_file)
        for param in a:
            replace_parameter_value(ssmc, param, put_value)
    if key:
        get_specific_param_value(ssmc, key)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='script to manage AWS SSM params')
    mutual_group = parser.add_argument_group('Parameters display options')
    mutually_exclusive = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive.add_argument('-e',
                                    '--environment',
                                    help='environment')
    mutually_exclusive.add_argument('-k',
                                    '--key',
                                    help='key of value to search')
    mutually_exclusive.add_argument('-f',
                                    '--parameters-file',
                                    help='paramater list to search')
    mutually_exclusive.add_argument('-v',
                                    '--value',
                                    help='Key of value to search')
    parser.add_argument('-r',
                        '--region',
                        help='region',
                        required=True)
    parser.add_argument('-p',
                        '--put_value',
                        default='',
                        help='put parameter')
    parser.add_argument('-w',
                        '--write-out',
                        help='Save results to a local file')
    parser.add_argument('-c',
                        '--count-params',
                        action='store_true',
                        help='count params')
    args = parser.parse_args()
    try:
        main(args.environment,
             args.key,
             args.parameters_file,
             args.region,
             args.put_value,
             args.value,
             args.write_out,
             args.count_params)
    except KeyboardInterrupt as e:
        print('\rYou pressed ctrl c')
        sys.exit(1)
