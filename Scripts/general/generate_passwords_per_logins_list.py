#!/usr/bin/env python3
"""
This script expects an argument containing a list of SSM params, separated by newline. 
It then counts the number of params and using an external site, it generates the same amount of passwords
and then prints each param name with its newly generated password value.
Script by Itai Ganot 2021
"""

import argparse
import requests


def generate_passwords(num_of_passwords: int):
    password_generator_site_url = 'https://www.passwordrandom.com/query?' \
                                  'command=password&format=json&count={}' \
                                  '&scheme=rvrrvCrVCvVNrNcVrNCvNrvnCvVcnrCv'.format(
                                      num_of_passwords)
    try:
        passwords_list = requests.get(
            url=password_generator_site_url).json()['char']
    except Exception as e:
        print(f"error: {e}")
    return passwords_list


def count_params_amount(params_file):
    params_file_line_count = len(open(params_file).readlines())
    return int(params_file_line_count)


def join_params_passwords(params_file, passwords_list):
    with open(params_file, 'r') as lfile:
        params = lfile.readlines()
        for pi, password in enumerate(passwords_list):
            if params[pi].endswith(':'):
                print("{} {}".format(params[pi].strip(), password), end="\n")
            else:
                print("{}: {}".format(params[pi].strip(), password), end="\n")


def main():
    parser = argparse.ArgumentParser(description='Joins lines containing param and passwords from '
                                                 'different files together')
    parser.add_argument('-p',
                        '--params-file',
                        type=str,
                        required=True,
                        help='List containing param names')
    args = parser.parse_args()

    params_amount = count_params_amount(args.params_file)
    passwords_list = generate_passwords(params_amount)
    join_params_passwords(args.params_file, passwords_list)


if __name__ == '__main__':
    main()
