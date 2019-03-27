#!/usr/bin/env python3
# This script can:
# 1. List all AWS SSM parameters and their values in a given region
# 2. Go through a file and get the values for all included keys
# 3. Return a specific value per a given key

import boto3
import argparse
import sys


def signal_handler(sig, frame):
    print(' You pressed Ctrl+C, exiting!')
    return signal_handler
    sys.exit(0)



def get_all_params_names(ssmclient, final_key):
    marker = None
    while True:
        paginator = ssmclient.get_paginator('describe_parameters')
        page_iterator = paginator.paginate(Filters=[{'Key': 'KeyId', 'Values': final_key}],
                                           PaginationConfig={'PageSize': 10,'NextToken': marker})

        for page in page_iterator:
            for param in page['Parameters']:
                param_value = ssmclient.get_parameter(Name=param['Name'],
                                                      WithDecryption=True)['Parameter']['Value']
                print('Name: %s | Value: %s' % (param['Name'], param_value))


def replace_parameter_value(ssmclient, key, put_value, final_key):
    final_keyid = str(final_key)
    try:
        put_request = ssmclient.put_parameter(Name=key,
                                              Value=put_value,
                                              Type='SecureString',
                                              KeyId=final_keyid,
                                              Overwrite=True)
    except Exception as e:
        print(e)
    else:
        print('Success!')



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

def main(all_params, key, parameters_file, region, env, put_value):
    ssmc = create_resource_instance(region)
    final_keyid = []
    keyid = 'alias/param_key_'
    final_keyid.extend(keyid + env)
    if parameters_file:
        a = load_file(parameters_file)
        for param in a:
            get_specific_param_value(ssmc, param.strip())
    if all_params:
        get_all_params_names(ssmc, final_keyid)
    if put_value:
        replace_parameter_value(ssmc, key, put_value, final_keyid)
    if key:
        get_specific_param_value(ssmc, key)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='script to manage AWS SSM params')
    mutual_group = parser.add_argument_group('Parameters display options')
    mutually_exclusive = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive.add_argument('-a',
                                    '--all',
                                    action='store_true',
                                    help='get all params')
    mutually_exclusive.add_argument('-k',
                                    '--key',
                                    help='key of value to search')
    mutually_exclusive.add_argument('-f',
                                    '--parameters-file',
                                    help='paramater list to search')
    parser.add_argument('-e',
                        '--environment',
                        help='environment',
                        required=True)
    parser.add_argument('-r',
                        '--region',
                        help='region',
                        required=True)
    parser.add_argument('-p',
                        '--put_value',
                        action='store_true',
                        default='',
                        help='put parameter')
    args = parser.parse_args()
    try:
        main(args.all,
             args.key,
             args.parameters_file,
             args.region,
             args.environment,
             args.put_value)
    except KeyboardInterrupt as e:
        print('\rYou pressed ctrl c')
        sys.exit(1)