#!/usr/bin/env python3
from datadog import initialize, api
import argparse


'''
This script mutes or unmutes a single or a bulk of Datadog monitor ids.
It expects the following parameters:
--monitor-ids: A single or a list of monitor ids
--api-key: Datadog api key to be used by the script
--app-key: Datadog app key to be used by the script
Mutually exclusive parameters:
--mute: Mutes a monitor
--unmute: Unmutes a monitor
Example commands:
./mute_monitors.py --api-key XXXX --app-key XXXX --monitor-ids 60285928 60283549 --mute
./mute_monitors.py --api-key XXXX --app-key XXXX --monitor-ids 60285928 --unmute

Script by Itai Ganot 2022
'''


def check_monitor_mute_status(monitor_id: str):
    monitor_details = api.Monitor.get(monitor_id)
    if len(monitor_details['options']['silenced']) == 0:
        return False
    else:
        return True


def mute_monitor(monitor_id: str):
    monitor_already_muted = check_monitor_mute_status(monitor_id)
    if monitor_already_muted:
        print(f"Monitor with id {monitor_id} is already muted!")
    else:
        try:
            api.Monitor.mute(monitor_id)
        except Exception as e:
            print(f"Unable to mute monitor, please contact Devops Team, error: {e}")
        print(f"Monitor with id {monitor_id} has been muted successfully!")


def unmute_monitor(monitor_id: str):
    monitor_already_unmuted = check_monitor_mute_status(monitor_id)
    if not monitor_already_unmuted:
        print(f"Monitor with id {monitor_id} is already unmuted!")
    else:
        try:
            api.Monitor.unmute(monitor_id)
        except Exception as e:
            print(f"Unable to unmute monitor, please contact Devops Team, error: {e}")
        print(f"Monitor with id {monitor_id} has been unmuted successfully!")


def main(action: str, monitor_ids: list, api_key: str, app_key: str):
    # Initializes datadog api
    options = {
        'api_key': api_key,
        'app_key': app_key
    }

    initialize(**options)

    if action == 'mute':
        for monitor_id in monitor_ids:
            mute_monitor(monitor_id)
    elif action == 'unmute':
        for monitor_id in monitor_ids:
            unmute_monitor(monitor_id)


if __name__ == '__main__':
    # Parsing of arguments supplied by the user
    parser = argparse.ArgumentParser(
        description='Mutes or unmutes a Datadog monitor')
    # Prevents user's ability to pass both --mute and --unmute together
    mutual_group = parser.add_argument_group('mutually exclusive arguments')
    mutually_exclusive = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive.add_argument('--mute',
                                    action='store_true',
                                    help='Mutes a monitor')
    mutually_exclusive.add_argument('-u',
                                    '--unmute',
                                    action='store_true',
                                    help='Unmutes a monitor')
    parser.add_argument('--monitor-ids',
                        required=True,
                        nargs='+',
                        help='Single or bulk of monitor ids separated by space')
    parser.add_argument('--api-key',
                        required=True,
                        help='Datadog api key')
    parser.add_argument('--app-key',
                        required=True,
                        help='Datadog app key')
    args = parser.parse_args()

    if not args.mute and not args.unmute:
        print('Error, please provide a --mute or --unmute parameter')
        exit(1)
    elif args.mute:
        action = 'mute'
    elif args.unmute:
        action = 'unmute'

    main(action,
         args.monitor_ids,
         args.api_key,
         args.app_key)
