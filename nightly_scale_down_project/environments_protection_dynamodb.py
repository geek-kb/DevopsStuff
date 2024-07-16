import boto3
import argparse
from datetime import datetime
import sys
import distutils
from distutils import util
import re
from dateutil import parser as p

"""
This script gets or updates the environments_protection table that resides in
eu-west-1 dynamodb (ops account).
The script requires the following IAM permissions:
dynamodb:DescribeTable
dynamodb:GetItem
dynamodb:UpdateItem
Script arguments:
action [-a] - The action you want to do on the table.
Available (action) options:
get-service, update-service, get-asg, update-asg, get-all-services, protect, unprotect, check-protection,
add-environment, add-issuer, check-environment-status, set-environment-status, get-protected-environments and
get-unprotected-environments.
resource_name [-r] - The service name to display or update
environment_name [-e] - The environment to display or update (Required for all actions but getting protected and
unprotected environments)
desired_value [-d] - The desired_val value to insert into the table (required only for update actions)
issuer_name [-i] - The name to set as the issuer of the process
aws_account_name [-n] - Required only when updating PRODUCT_NAME autoscaling group
env_status [-s] - Sets is_running on an environment (Accepts: on/off/true/false/yes/no)
Examples:
python3 environments_protection_dynamodb.py -e qa-devops-1 -a get-service -r ops-machine
python3 environments_protection_dynamodb.py -e qa-devops-1 -a update-service -r ops-machine -d 1
python3 environments_protection_dynamodb.py -e qa-devops-1 -a get-asg -r qa-devops-1-ECS-PRODUCT_NAME -n ACCOUNT_TYPE_1
python3 environments_protection_dynamodb.py -e qa-devops-1 -a update-asg -r qa-devops-1-ECS-PRODUCT_NAME -d 5 -n ACCOUNT_TYPE_1
python3 environments_protection_dynamodb.py -e qa-devops-1 -a get-all-services
python3 environments_protection_dynamodb.py -e qa-devops-1 -a add-issuer -i geek-kb
python3 environments_protection_dynamodb.py -e qa-devops-1 -a add-environment
python3 environments_protection_dynamodb.py -e qa-devops-1 -a check-protection
python3 environments_protection_dynamodb.py -e qa-devops-1 -a protect -t "10-11-22 22:00:00"
python3 environments_protection_dynamodb.py -a get-protected-environments
python3 environments_protection_dynamodb.py -e qa-devops-1 -a unprotect
python3 environments_protection_dynamodb.py -e qa-devops-1 -a set-environment-status -s on
python3 environments_protection_dynamodb.py -e qa-devops-1 -a check-environment-status
python3 environments_protection_dynamodb.py -a get-unprotected-environments

Code by Itai Ganot, 2022
"""


def check_protection_status(environment_name, table):
    date_time_str = datetime.now().strftime("%d-%m-%Y %H:%M")
    try:
        response_end_protection_ts_value = table.get_item(
            Key={"environment_name": f"{environment_name}"})["Item"]["end_protection_ts"]
    except Exception as e:
        print(f"Environment {environment_name} has no value: {e}")
        sys.exit(1)
    else:
        if response_end_protection_ts_value == "null":
            return False
        elif isinstance(response_end_protection_ts_value, str):
            current_end_protection_ts = p.parse(response_end_protection_ts_value)
            now_ts = p.parse(date_time_str, dayfirst=True)
            if current_end_protection_ts > now_ts:
                end_protection_date = check_end_protection_date(environment_name, table)
                return end_protection_date
            else:
                return False
        else:
            pass


def check_end_protection_date(environment_name, table):
    response_end_protection_ts_value = table.get_item(
            Key={"environment_name": f"{environment_name}"})["Item"]["end_protection_ts"]
    return response_end_protection_ts_value


def _update_protection_timestamp(environment_name, date_value, table):
    date_format = "%d-%m-%Y %H:%M"
    now_str = datetime.now().strftime(date_format)
    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression=f"SET end_protection_ts = :end_protection_tsVal",
        ExpressionAttributeValues={
            ":end_protection_tsVal": str(date_value),
        }
    )
    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression=f"SET protection_update_timestamp = :protection_update_timestampVal",
        ExpressionAttributeValues={
            ":protection_update_timestampVal": now_str,
        }
    )


def list_environments(action, table):
    data = table.scan()['Items']
    protected_envs_list = []
    unprotected_envs_list = []
    for env in data:
        protection_state = check_protection_status(env['environment_name'], table)
        environment_protection_date = check_end_protection_date(env['environment_name'], table)
        if not protection_state:
            unprotected_envs_list.append(env['environment_name'])
        else:
            protected_envs_list.append(f"{env['environment_name']}: {environment_protection_date}")
    if action == 'get-protected-environments':
        if len(protected_envs_list) > 0:
            print(f"The following environments are protected:")
            [print(env) for env in protected_envs_list]
        else:
            print(f"There are no protected environments")
    elif action == 'get-unprotected-environments':
        if len(unprotected_envs_list) > 0:
            print(f"The following environments are unprotected:")
            [print(env) for env in unprotected_envs_list]
        else:
            print(f"There are no unprotected environments!")


def check_environment_status(environment_name, table):
    environment_status = table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["is_running"]
    if environment_status:
        print(f"Environment {environment_name} is running!")
    else:
        print(f"Environment {environment_name} is not running!")


def set_environment_status(environment_name, status, table):
    value = bool(distutils.util.strtobool(status))
    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression=f"SET is_running = :runningVal",
        ExpressionAttributeValues={
            ":runningVal": value
        }
    )
    print(
        f"Success: Successfully set is_running={value} on environment {environment_name}!"
    )


def protect_unprotect_environment(environment_name, action, date_value, table):
    date_format = "%d-%m-%Y %H:%M"
    now_str = datetime.now().strftime(date_format)
    current_protection_status = check_protection_status(environment_name, table)
    now_ts = p.parse(now_str, dayfirst=True)
    date_value_str = date_value.strftime(date_format)
    date_value_ts = datetime.strptime(date_value_str, date_format)
    if action == "protect" and isinstance(current_protection_status, str):
        current_env_protection_value_in_table_str = check_end_protection_date(environment_name, table)
        current_env_protection_value_in_table_ts = p.parse(current_env_protection_value_in_table_str, dayfirst=True)
        if date_value_ts == current_env_protection_value_in_table_ts:
            print("Environment protection date already matches the value in the table!")
        elif date_value_ts > current_env_protection_value_in_table_ts:
            ext_formatted_time = datetime.strftime(date_value_ts, date_format)
            _update_protection_timestamp(environment_name, ext_formatted_time, table)
            print(f"Environment protection has been extended until"
                  f" {str(ext_formatted_time).replace(' ', ' at ')}!")
        elif date_value_ts < current_env_protection_value_in_table_ts:
            ext_formatted_time = datetime.strftime(date_value_ts, date_format)
            _update_protection_timestamp(environment_name, ext_formatted_time, table)
            print(f"Environment {environment_name} has been protected until"
                  f" {str(ext_formatted_time).replace(' ', ' at ')}!")
    elif action == "protect" and not current_protection_status:
        if date_value_ts > now_ts:
            formatted_date_value = datetime.strftime(date_value_ts, date_format)
            _update_protection_timestamp(environment_name, formatted_date_value, table)
            print(f"Environment {environment_name} has been protected until"
                  f" {str(formatted_date_value).replace(' ', ' at ')}!")
        else:
            print(f"End protection date has already passed, env {environment_name} is not protected!")
    elif action == "unprotect" and current_protection_status == 'null':
        print(f"Environment {environment_name} is already unprotected!")
    elif action == "unprotect" and isinstance(current_protection_status, str):
        _update_protection_timestamp(environment_name, 'null', table)
        print(f"Disabled protection for environment {environment_name}!")


def add_issuer(environment_name, issuer, table):
    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression=f"SET issuer = :issuerName",
        ExpressionAttributeValues={
            ":issuerName": f"{issuer}",
        }
    )
    print(f"Updated issuer {issuer} in dynamodb table!")


def compare_current_and_desired_asg_values(
        environment_name: str, resource_name: str, action: str, desired_value: str, table
):
    new_desiredcapacity_value = desired_value
    current_desiredcapacity_value = get_asg_desired_value(environment_name,
                                                          resource_name,
                                                          action,
                                                          table)
    if current_desiredcapacity_value == new_desiredcapacity_value:
        return True
    else:
        return False


def add_environment_to_table(environment_name, table):
    timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
    table.put_item(
        TableName="environments_protection",
        Item={
            "environment_name": f"{environment_name}",
            "ACCOUNT_TYPE_2_PRODUCT_NAME_asg": {
                "desired_value": "2",
                "last_updated": timestamp
            },
            "ACCOUNT_TYPE_1_PRODUCT_NAME_asg": {
                "desired_value": "2",
                "last_updated": timestamp
            },
            "issuer": "",
            "end_protection_ts": timestamp,
            "protection_update_timestamp": "",
            "is_running": False,
            "services_task_count": [
                {
                    "name": "ops_machine",
                    "desired_value": 0,
                    "last_updated": f"{timestamp}"
                }
            ]
        }
    )
    print(f"Environment {environment_name} has been added to dynamodb!")


def _add_service_to_table(environment_name, service_name, desired_value, table):
    timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression="SET services_task_count = list_append(services_task_count, :newService)",
        ExpressionAttributeValues={
            ':newService': [
                {"desired_value": f"{desired_value}", "last_updated": f"{timestamp}", "name": f"{service_name}"}
            ]
        }
    )
    print(f'New service {service_name} added to dynamodb table in {environment_name}!')


def get_service_desired_from_table(environment_name: str, service_name: str, table):
    response = table.get_item(Key={"environment_name": f"{environment_name}"})
    item = response["Item"]
    for service in item["services_task_count"]:
        if service["name"] == service_name:
            return int(service["desired_value"])


def get_service_items(environment_name, table):
    table_items = table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["services_task_count"]
    return table_items


def get_asg_desired_value(environment_name, resource_name, action, table):
    table_items = table.get_item(Key={"environment_name": f"{environment_name}"})["Item"][resource_name]
    if table_items["desired_value"] != '':
        current_desired_val = table_items["desired_value"]
        if action == "update-asg":
            return current_desired_val
        elif action == "get-asg":
            print(current_desired_val)
    else:
        print(f'Desired value of resource {resource_name} is empty')


def get_service(environment_name, resource_name, table):
    table_items = table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["services_task_count"]
    for table_item in table_items:
        name = table_item["name"]
        desired_value = table_item["desired_value"]
        last_updated = table_item["last_updated"]
        if name == resource_name:
            print(
                f"service_name: {name} | desired: {desired_value} | last_updated: {last_updated}"
            )
            return
    print(f"Service {resource_name} cannot be found in the table! exiting")
    sys.exit(1)


def get_all_services(environment_name, table):
    table_items = table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["services_task_count"]
    for i, table_item in enumerate(table_items):
        name = table_item["name"]
        desired_value = table_item["desired_value"]
        last_updated = table_item["last_updated"]
        print(
            f"service_name: {name} | "
            f"desired_value: {desired_value} | "
            f"last_updated: {last_updated} | "
            f"table_index: {i}"
        )


def update_service(new_desired_value, service_name, environment_name, table):
    service_just_added = False
    timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
    current_desired_value = get_service_desired_from_table(environment_name, service_name, table)
    if current_desired_value is None:
        _add_service_to_table(environment_name, service_name, new_desired_value, table)
        current_desired_value = get_service_desired_from_table(environment_name, service_name, table)
        service_just_added = True
    if not service_just_added:
        if int(current_desired_value) != int(new_desired_value):
            services = get_service_items(environment_name, table)
            for i, elem in enumerate(services):
                name = elem["name"]
                # print(f"name: {name} service_name: {service_name}")
                if name == service_name:
                    table.update_item(
                        Key={"environment_name": f"{environment_name}"},
                        UpdateExpression=f"SET services_task_count[{i}].desired_value = :servicesVal",
                        ExpressionAttributeValues={
                            ":servicesVal": int(new_desired_value),
                        }
                    )
                    table.update_item(
                        Key={"environment_name": f"{environment_name}"},
                        UpdateExpression=f"SET services_task_count[{i}].last_updated = :timestampVal",
                        ExpressionAttributeValues={
                            ":timestampVal": timestamp,
                        }
                    )
                    print(
                        f"Service {service_name} has been updated with value: {new_desired_value}"
                    )
        else:
            print(f"Current desired value of service {service_name} already matches new desired "
                  f"value, not doing anything")


def update_asg(environment_name, resource_name, desired_value, table):
    timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
    new_desired_capacity_value = desired_value

    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression=f"SET {resource_name}.desired_value = :asgdesiredVal",
        ExpressionAttributeValues={
            ":asgdesiredVal": int(new_desired_capacity_value),
        }
    )
    table.update_item(
        Key={"environment_name": f"{environment_name}"},
        UpdateExpression=f"SET {resource_name}.last_updated = :timestampVal",
        ExpressionAttributeValues={
            ":timestampVal": timestamp,
        }
    )
    print(
        f"Success! {resource_name} autoscaling group has been updated successfully with the following desired"
        f" values: {new_desired_capacity_value}"
    )


def main(environment_name, action, table, desired_value=None, resource_name=None):
    date_format = "%d-%m-%Y %H:%M"
    if args.action == 'add-environment':
        add_environment_to_table(environment_name, table)
    if args.action == 'check-protection' and environment_name is None:
        print('Environment name not provided, exiting.')
        sys.exit(1)
    if args.action == 'check-protection':
        protection_status = check_protection_status(environment_name, table)
        if not protection_status:
            print(f"Environment {environment_name} is not protected!")
        else:
            protection_status_ts = p.parse(protection_status, dayfirst=True)
            formatted_date = datetime.strftime(protection_status_ts, date_format)
            print(f"Environment {environment_name} is protected until {str(formatted_date).replace(' ', ' at ')}!")
    if args.action == 'protect' or args.action == 'unprotect':
        protect_unprotect_environment(environment_name, action, date_value, table, )
    if action == "update-service":
        update_service(desired_value, resource_name, environment_name, table)
    if action == "get-service":
        get_service(environment_name, resource_name, table)
    if action == "update-asg":
        matching_values = compare_current_and_desired_asg_values(
            environment_name, resource_name, action, desired_value, table
        )
        if not matching_values:
            update_asg(environment_name, resource_name, desired_value, table)
        else:
            print(f"Passed values are already the currently configured ones")
    if action == "get-asg":
        get_asg_desired_value(environment_name, resource_name, action, table)
    if action == "get-all-services":
        get_all_services(environment_name, table)


if __name__ == "__main__":
    # Parsing of arguments supplied by the user
    parser = argparse.ArgumentParser(
        description="Updates or reads desired counts of ecs services and protects/unprotects an environment"
    )
    parser.add_argument(
        "-e", "--environment-name", help="Environment name"
    )
    parser.add_argument(
        "-a", "--action", help="update or get from dynmodb table", required=True
    )
    parser.add_argument("-r", "--resource-name", help="resource name")
    parser.add_argument("-d", "--desired-value", help="Value to update")
    parser.add_argument("-n", "--aws-account-name", help="ACCOUNT_TYPE_1 or ACCOUNT_TYPE_2")
    parser.add_argument("-i", "--issuer-name", help="issuer")
    parser.add_argument("-s", "--env-status", help="running (true)/ not running (false)")
    parser.add_argument("-t", "--protection-date", help="end protection date")
    args = parser.parse_args()

    if args.action == 'set-environment-status' and args.env_status is None:
        print('Action set-environment-status requires passing true or false')
        sys.exit(1)
    if args.action == 'protect' or args.action == 'unprotect':
        if args.resource_name is not None or args.desired_value is not None:
            print(
                "Protecting or unprotecting an environment requires passing only environment name and"
                "protection status, exiting."
            )
            sys.exit(1)
    if str(args.action).endswith("-service"):
        if "-" in args.resource_name:
            resource_name = str(args.resource_name).replace("-", "_")
        else:
            resource_name = args.resource_name
    if "get" in args.action and args.desired_value is not None:
        print(f"Desired value is not required for get actions, exiting.")
        sys.exit(1)
    if "update" in args.action and args.desired_value is None:
        print("Update action requires passing desired value/s, exiting.")
        sys.exit(1)
    if ("asg" in args.action) and (args.resource_name is None or args.aws_account_name is None):
        print("Please provide autoscaling group name [-r] switch and aws account name [-n], exiting")
        sys.exit(1)
    elif "update-asg" in args.action and (
            args.resource_name == f"{args.environment_name}-ECS-dl-processor" or
            args.resource_name == f"{args.environment_name}-ECS-PRODUCT_NAME-web"):
        print(f"{args.resource_name} autoscaling group is managed by a capacity provider, exiting.")
        sys.exit(1)
    if "asg" in args.action:
        if str(args.resource_name).endswith("ECS-PRODUCT_NAME"):
            resource_name = f"{args.aws_account_name}_PRODUCT_NAME_asg"
        else:
            resource_name = args.resource_name
    if args.action == "add-issuer" and args.issuer_name is None:
        print("Please provide issuer name")
        sys.exit(1)
    if args.action == "protect" and args.protection_date is None:
        print(f"End protection date not provided! exiting.")
        sys.exit(1)
    elif args.action == "protect" and args.protection_date is not None:
        date_value = p.parse(args.protection_date, dayfirst=True)
    if args.action == "unprotect":
        date_value = datetime.now()
    if args.action == "check-protection":
        resource_name = None

    table_name = 'environments_protection'
    client = boto3.resource("dynamodb").Table(table_name)

    if args.action == 'get-unprotected-environments' or args.action == 'get-protected-environments':
        list_environments(args.action, client)
        sys.exit(0)
    if args.action == "add-issuer":
        add_issuer(args.environment_name, args.issuer_name, client)
        sys.exit(0)

    if args.action == "check-environment-status":
        check_environment_status(args.environment_name, client)
        sys.exit(0)

    if args.action == "set-environment-status":
        set_environment_status(args.environment_name, args.env_status, client)
        sys.exit(0)

    if args.action == "protect" or args.action == "unprotect":
        main(
            args.environment_name,
            args.action,
            client
        )
    elif args.action == "get-all-services" or args.action == "add-environment":
        main(
            args.environment_name,
            args.action,
            client,
            args.desired_value
        )
    else:
        main(
            args.environment_name,
            args.action,
            client,
            args.desired_value,
            resource_name
        )
