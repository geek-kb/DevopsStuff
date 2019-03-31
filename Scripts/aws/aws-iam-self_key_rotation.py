#!/usr/bin/env python3

import boto3
import datetime
import argparse
from datetime import timedelta

class User:
    def __init__(self):
        self.iam = boto3.client('iam')
        response = self.iam.get_user()
        self.username = response['User']['UserName']
        self.userid = response['User']['UserId']
        self.arn = response['User']['Arn']
        self.TodayDate = datetime.datetime.today()
        self.MaxKeyAge = 90


    def print_user_info(self):
        print('UserName: {}\nUserId: {}\nUserArn: {}'.format(self.username,
                                                         self.userid,
                                                         self.arn))


    def create_access_key(self, username):
        response = self.iam.create_access_key(
            UserName=username
        )['AccessKey']
        print('New Access / Secret keys have been created!\nAccess Key: {'
              '}\nSecret Key: {}'.format(
            response['AccessKeyId'],
            response['SecretAccessKey']))


    def disable_access_key(self, UserName, key):
        response = self.iam.update_access_key(
            UserName=UserName,
            AccessKeyId=key,
            Status='Inactive'
        )['ResponseMetadata']
        if response['HTTPStatusCode'] == 200:
            print('Key {} disabled!'.format(key))



    def check_users_access_key(self):
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
            )['AccessKeyLastUsed']
            keydate_delta = TodayDate_notz - CreateDate_notz
            td = timedelta(days=self.MaxKeyAge) - keydate_delta
            key_age = self.MaxKeyAge - td.days
            print('TodayDate: {},\nCreation Date: {},\nLast Used: {}'
                  '\nTime Delta (since creation): {}\nDays Delta '
                  '(since creation): {}'.format(
                TodayDate_notz,
                CreateDate_notz,
                KeyLastUsed,
                keydate_delta,
                key_age))
            if td.days > self.MaxKeyAge:
                print('Rotation not required yet! key #{} age (in days) is: '
                      '{} and '
                      'lower than default [{}].'.format(i + 1,
                                               key_age,
                                               self.MaxKeyAge))
            else:
                print('Rotation required! key #{} age ()in days is: {} and '
                      'larger than MaxKeyAge [{}].'.format(i + 1,
                                                           key_age,
                                                           self.MaxKeyAge))
                self.create_access_key(self.username)
                self.disable_access_key(self.username, eachkey)


def main(display, rotate):
    current_user = User()
    if display:
        current_user.print_user_info()
    elif rotate:
        current_user.check_users_access_key()
    else:
        print('No arguments supplied!')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='script rorate AWS access keys')
    mutual_group = parser.add_argument_group()
    mutually_exclusive = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive.add_argument('-d',
                                    '--display',
                                    action='store_true',
                                    help='Display Access Key information')
    mutually_exclusive.add_argument('-r',
                                    '--rotate',
                                    action='store_true',
                                    help='Rotate keys as necessary')
    args = parser.parse_args()
    try:
        main(args.display,
             args.rotate)
    except Exception as e:
        print(e)

