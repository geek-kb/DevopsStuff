#!/usr/bin/env python3
"""This script checks current's user's AWS access key age and rotates it
if it's older than 90 days.
The rotate works like so:
1. Creation of a new AWS access key and secret key and printing them to screen.
2. Disables the key which needs to be rotated
Exit codes:
0 = Success
1 = No AWS access key is configured or key is invalid
2 = Max keys quota exceeded! only 2 allowed
# Script by Itai Ganot 2019. lel@lel.bz
"""

import boto3
import datetime
import argparse
import sys
from datetime import timedelta
from botocore.exceptions import ClientError


class User:
    def __init__(self,
                 iam,
                 response,
                 username,
                 userid,
                 arn,
                 TodayDate,
                 MaxKeyAge):
        self.iam = iam
        self.response = response
        self.username = username
        self.userid = userid
        self.arn = arn
        self.TodayDate = TodayDate
        self.MaxKeyAge = MaxKeyAge


    def print_user_info(self):
        """Prints current user information (based on configuration
        of ~/.aws/credentials)
        """
        print('UserName: {}\nUserId: {}\nUserArn: {}'.format(self.username,
                                                         self.userid,
                                                         self.arn))


    def create_access_key(self, username):
        # Creates a new access and secret key and prints them to STDOUT
        try:
            response = self.iam.create_access_key(
                UserName=username
            )['AccessKey']
            print('New Access / Secret keys have been created!\nAccess Key: {'
                  '}\nSecret Key: {}'.format(
                response['AccessKeyId'],
                response['SecretAccessKey']))
        except ClientError as e:
            if e.response['Error']['Code'] == 'LimitExceeded':
                print('Error: Max keys quota exceeded! only 2 allowed')
                sys.exit(2)


    def disable_access_key(self, UserName, key):
        # Disables an active access key
        try:
            response = self.iam.update_access_key(
                UserName=UserName,
                AccessKeyId=key,
                Status='Inactive'
            )['ResponseMetadata']
            if response['HTTPStatusCode'] == 200:
                print('Key {} disabled!'.format(key))
        except Exception as e:
            print(e)


    def check_or_rotate_users_access_key(self):
        """Checks the age of a user's access keys and rotates them if
        equal or larger than the value set in MaxKeyAge
        """
        self.Keys = []
        self.iam = boto3.client('iam')
        response = self.iam.list_access_keys()
        [self.Keys.extend(AccessKeyMeta['AccessKeyId'] for AccessKeyMeta in
          response['AccessKeyMetadata'])]

        for i, eachkey in enumerate(self.Keys):
            print('--------======== key #{}: {} ========--------'.format(i + 1,
                                                                eachkey))
            self.AccessKeyCreateDate = response['AccessKeyMetadata'][i][
                'CreateDate']
            CreateDate = self.AccessKeyCreateDate
            CreateDate_notz = CreateDate.replace(tzinfo=None)
            TodayDate_notz = self.TodayDate.replace(tzinfo=None)
            self.KeyStatus = response['AccessKeyMetadata'][i]['Status']
            messge = 'User: {} \
            Key creation date: {} \
            Key Status: {}'.format(
                self.username,
                CreateDate,
                self.KeyStatus)
            print(messge)
            KeyLastUsed = self.iam.get_access_key_last_used(
                AccessKeyId=eachkey
            )['AccessKeyLastUsed']['LastUsedDate']
            keydate_delta = TodayDate_notz - CreateDate_notz
            td = timedelta(days=self.MaxKeyAge) - keydate_delta
            key_age = self.MaxKeyAge - td.days
            print('TodayDate: {}\nCreation Date: {}\nLast Used: {}'
                  '\nTime Delta (since creation): {}\nDays Delta '
                  '(since creation): {}'.format(
                TodayDate_notz,
                CreateDate_notz,
                KeyLastUsed,
                keydate_delta,
                key_age))
            if td.days < self.MaxKeyAge:
                print('Rotation not required yet! key #{} age (in days)'\
                      ' is: {} and lower than default [{}].'\
                      .format(i + 1,
                              key_age,
                              self.MaxKeyAge))
            else:
                print('Rotation required! key #{} age ()in days is: {} and '
                      'larger than MaxKeyAge [{}].'.format(i + 1,
                                                           key_age,
                                                           self.MaxKeyAge))
                self.create_access_key(self.username)
                self.disable_access_key(self.username, eachkey)

try:
    iam = boto3.client('iam')
    response = iam.get_user()
    username = response['User']['UserName']
    userid = response['User']['UserId']
    arn = response['User']['Arn']
    TodayDate = datetime.datetime.today()
    MaxKeyAge = 90
except ClientError as e:
    if e.response['Error']['Code'] == 'InvalidClientTokenId':
        print('Error: No AWS access key is configured or key is invalid')
        sys.exit(1)

def main(display, rotate):
    """Based on the arguments supplied, this function decides how to continue
    and also initializes the class.
    """
    current_user = User(iam,
                        response,
                        username,
                        userid,
                        arn,
                        TodayDate,
                        MaxKeyAge)
    if display:
        current_user.print_user_info()
    elif rotate:
        current_user.check_or_rotate_users_access_key()
    else:
        print('No arguments supplied!')


if __name__ == '__main__':
    # Parsing of arguments supplied by the user
    parser = argparse.ArgumentParser(
        description='script rorate AWS access keys')
    mutual_group = parser.add_argument_group()
    mutually_exclusive = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive.add_argument('-d',
                                    '--display-user',
                                    action='store_true',
                                    help='Display Access Key information')
    mutually_exclusive.add_argument('-r',
                                    '--rotate',
                                    action='store_true',
                                    help='Rotate keys as necessary')
    args = parser.parse_args()
    try:
        main(args.display_user,
             args.rotate)
    except Exception as e:
        print(e)
