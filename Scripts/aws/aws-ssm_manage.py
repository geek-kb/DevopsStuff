#!/usr/bin/env python3
# This script can:
# 1. List all AWS SSM parameters and their values in a given region
# 2. Go through a file and get the values for all included keys
# 3. Return a specific value per a given key

import boto3
import argparse


def get_all_params_names(ssmclient):
    marker = None
    while True:
        paginator = ssmclient.get_paginator('describe_parameters')
        page_iterator = paginator.paginate(PaginationConfig={'PageSize': 10, 'NextToken': marker})
        for page in page_iterator:
            for param in page['Parameters']:
                param_value = ssmclient.get_parameter(Name=param['Name'],
                                                      WithDecryption=True)['Parameter']['Value']
                print('Name: %s | Value: %s' % (param['Name'], param_value))


def get_specific_param_value(ssmclient, search_value):
    try:
        specific_param_value = ssmclient.get_parameter(Name=search_value,
                                           WithDecryption=True)['Parameter']
        print("Name: %s | Value: %s " % (search_value, specific_param_value['Value']))
        return specific_param_value
    except Exception as e:
        print('No such parameter found: %s, Error: %s' % (search_value, e))


def load_file(params_list):
    loaded_params_list = []
    with open(params_list, 'r', encoding='ascii') as f:
        loaded_params_list.extend([ i for i in f.readlines() ])
    return loaded_params_list


def create_resource_instance(region):
    ssmclient = boto3.client('ssm', region_name=region)
    return ssmclient

def main(all_params, key, parameters_file, region):
    ssmc = create_resource_instance(region)
    if parameters_file:
        a = load_file(parameters_file)
        [get_specific_param_value(ssmc, param.strip()) for param in a]
    if all_params:
        get_all_params_names(ssmc)
    if key:
        get_specific_param_value(ssmc, key)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='script')
    mutual_group = parser.add_argument_group('Mutually exclusive arguments')
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
    parser.add_argument('-r',
                        '--region',
                        help='region',
                        required=True)
    args = parser.parse_args()
    main(args.all,
         args.key,
         args.parameters_file,
         args.region)