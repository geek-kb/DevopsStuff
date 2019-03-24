#!/usr/bin/env python3
# This script can:
# 1. List all AWS SSM parameters and their values in a given region
# 2. Go through a file and get the values for all included keys
# 3. Return a specific value per a given key
# TBC...

import boto3
import argparse
import sys


def get_all_params_names(ssmclient, env):
    final_keyid = 'alias/param_key_{}'.format(env)
    print('Working on env: %s' % env)
    marker = None
    count = 0
    while True:
        paginator = ssmclient.get_paginator('describe_parameters')
        page_iterator = paginator.paginate(Filters=[{'Key': 'KeyId', 'Values': [final_keyid]}],
                                           PaginationConfig={'PageSize': 10,'NextToken': marker})

        for page in page_iterator:
            for param in page['Parameters']:
                count += 1
                param_value = ssmclient.get_parameter(Name=param['Name'],
                                                      WithDecryption=True)['Parameter']['Value']
                print('#%i Name: %s | Value: %s | KeyId: %s' % (count, param['Name'], param_value, final_keyid))


def replace_parameter_value(ssmclient, key, put_value):
    try:
        ssmclient.put_parameter(Name=key,
                                Value=put_value,
                                Type='SecureString',
                                Overwrite=True)
    except Exception as e:
        print(e)
    else:
        print('Key %s successfully updated!' % key.strip())


def get_key_of_value(ssmclient, value):
    marker = None
    while True:
        paginator = ssmclient.get_paginator('describe_parameters')
        page_iterator = paginator.paginate(PaginationConfig={'PageSize': 10,'NextToken': marker})
        for page in page_iterator:
            for param in page['Parameters']:
                sys.stdout.write("-")
                sys.stdout.flush()
                param_name = param['Name']
                param_value = ssmclient.get_parameter(Name=param_name,
                                        WithDecryption=True)['Parameter']
                if param_value is value:
                    print('Value %s found in parameter %s' % (value, param_name))


def get_specific_param_value(ssmclient, search_value):
    try:
        specific_param_value = ssmclient.get_parameter(Name=search_value,
                                                       WithDecryption=True)['Parameter']
        print("Name: %s | Value: %s " % (search_value, specific_param_value['Value']))
        return specific_param_value
    except Exception as e:
        print('No such parameter found: %s, Error: %s' % (search_value, e))


def load_file(params_list):
    with open(params_list, 'r', encoding='ascii') as f:
        return f.readlines()


def create_resource_instance(region):
    ssmclient = boto3.client('ssm', region_name=region)
    return ssmclient

def main(env, key, parameters_file, region, put_value, value):
    ssmc = create_resource_instance(region)
    if parameters_file:
        try:
            a = load_file(parameters_file)
            for param in a:
                get_specific_param_value(ssmc, param.strip())
        except FileNotFoundError as e:
            e = str(e)
            print(e[10:])
    if value:
        get_key_of_value(ssmc, value)
    if env:
        get_all_params_names(ssmc, env)
    if put_value and key:
        replace_parameter_value(ssmc, key, put_value)
    if put_value and parameters_file:
        a = load_file(parameters_file)
        for param in a:
            replace_parameter_value(ssmc, param, put_value)
    if key:
        get_specific_param_value(ssmc, env)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='script to manage AWS SSM params')
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
    args = parser.parse_args()
    try:
        main(args.environment,
             args.key,
             args.parameters_file,
             args.region,
             args.put_value,
             args.value)
    except KeyboardInterrupt as e:
        print('\rYou pressed ctrl c')
        sys.exit(1)