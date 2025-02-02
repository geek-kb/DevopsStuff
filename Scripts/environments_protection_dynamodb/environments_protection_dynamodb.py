import boto3
import argparse
from datetime import datetime
import sys
import distutils
from distutils import util
import re
from dateutil import parser as p

class DynamoDBHandler:
    def __init__(self, table_name):
        self.table = boto3.resource("dynamodb").Table(table_name)

    def check_protection_status(self, environment_name):
        date_time_str = datetime.now().strftime("%d-%m-%Y %H:%M")
        try:
            response_end_protection_ts_value = self.table.get_item(
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
                    return self.check_end_protection_date(environment_name)
                else:
                    return False

    def check_end_protection_date(self, environment_name):
        response_end_protection_ts_value = self.table.get_item(
                Key={"environment_name": f"{environment_name}"})["Item"]["end_protection_ts"]
        return response_end_protection_ts_value

    def update_protection_timestamp(self, environment_name, date_value):
        date_format = "%d-%m-%Y %H:%M"
        now_str = datetime.now().strftime(date_format)
        self.table.update_item(
            Key={"environment_name": f"{environment_name}"},
            UpdateExpression=f"SET end_protection_ts = :end_protection_tsVal",
            ExpressionAttributeValues={":end_protection_tsVal": str(date_value)}
        )
        self.table.update_item(
            Key={"environment_name": f"{environment_name}"},
            UpdateExpression=f"SET protection_update_timestamp = :protection_update_timestampVal",
            ExpressionAttributeValues={":protection_update_timestampVal": now_str}
        )

    def list_environments(self, action):
        data = self.table.scan()['Items']
        protected_envs_list = []
        unprotected_envs_list = []
        for env in data:
            protection_state = self.check_protection_status(env['environment_name'])
            environment_protection_date = self.check_end_protection_date(env['environment_name'])
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

    def check_environment_status(self, environment_name):
        environment_status = self.table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["is_running"]
        if environment_status:
            print(f"Environment {environment_name} is running!")
        else:
            print(f"Environment {environment_name} is not running!")

    def set_environment_status(self, environment_name, status):
        value = bool(distutils.util.strtobool(status))
        self.table.update_item(
            Key={"environment_name": f"{environment_name}"},
            UpdateExpression=f"SET is_running = :runningVal",
            ExpressionAttributeValues={":runningVal": value}
        )
        print(f"Success: Successfully set is_running={value} on environment {environment_name}!")

    def protect_unprotect_environment(self, environment_name, action, date_value):
        date_format = "%d-%m-%Y %H:%M"
        now_str = datetime.now().strftime(date_format)
        current_protection_status = self.check_protection_status(environment_name)
        now_ts = p.parse(now_str, dayfirst=True)
        date_value_str = date_value.strftime(date_format)
        date_value_ts = datetime.strptime(date_value_str, date_format)
        if action == "protect" and isinstance(current_protection_status, str):
            current_env_protection_value_in_table_str = self.check_end_protection_date(environment_name)
            current_env_protection_value_in_table_ts = p.parse(current_env_protection_value_in_table_str, dayfirst=True)
            if date_value_ts == current_env_protection_value_in_table_ts:
                print("Environment protection date already matches the value in the table!")
            elif date_value_ts > current_env_protection_value_in_table_ts:
                ext_formatted_time = datetime.strftime(date_value_ts, date_format)
                self.update_protection_timestamp(environment_name, ext_formatted_time)
                print(f"Environment protection has been extended until {str(ext_formatted_time).replace(' ', ' at ')}!")
            elif date_value_ts < current_env_protection_value_in_table_ts:
                ext_formatted_time = datetime.strftime(date_value_ts, date_format)
                self.update_protection_timestamp(environment_name, ext_formatted_time)
                print(f"Environment {environment_name} has been protected until {str(ext_formatted_time).replace(' ', ' at ')}!")
        elif action == "protect" and not current_protection_status:
            if date_value_ts > now_ts:
                formatted_date_value = datetime.strftime(date_value_ts, date_format)
                self.update_protection_timestamp(environment_name, formatted_date_value)
                print(f"Environment {environment_name} has been protected until {str(formatted_date_value).replace(' ', ' at ')}!")
            else:
                print(f"End protection date has already passed, env {environment_name} is not protected!")
        elif action == "unprotect" and current_protection_status == 'null':
            print(f"Environment {environment_name} is already unprotected!")
        elif action == "unprotect" and isinstance(current_protection_status, str):
            self.update_protection_timestamp(environment_name, 'null')
            print(f"Disabled protection for environment {environment_name}!")

    def add_issuer(self, environment_name, issuer):
        self.table.update_item(
            Key={"environment_name": f"{environment_name}"},
            UpdateExpression=f"SET issuer = :issuerName",
            ExpressionAttributeValues={":issuerName": f"{issuer}"}
        )
        print(f"Updated issuer {issuer} in dynamodb table!")

    def add_environment_to_table(self, environment_name):
        timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
        self.table.put_item(
            TableName="environments_protection",
            Item={
                "environment_name": f"{environment_name}",
                "first_account_asg": {
                    "desired_value": "2",
                    "last_updated": timestamp
                },
                "second_account_asg": {
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

    def update_service(self, new_desired_value, service_name, environment_name):
        service_just_added = False
        timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
        current_desired_value = self.get_service_desired_from_table(environment_name, service_name)
        if current_desired_value is None:
            self._add_service_to_table(environment_name, service_name, new_desired_value)
            current_desired_value = self.get_service_desired_from_table(environment_name, service_name)
            service_just_added = True
        if not service_just_added:
            if int(current_desired_value) != int(new_desired_value):
                services = self.get_service_items(environment_name)
                for i, elem in enumerate(services):
                    name = elem["name"]
                    if name == service_name:
                        self.table.update_item(
                            Key={"environment_name": f"{environment_name}"},
                            UpdateExpression=f"SET services_task_count[{i}].desired_value = :servicesVal",
                            ExpressionAttributeValues={":servicesVal": int(new_desired_value)}
                        )
                        self.table.update_item(
                            Key={"environment_name": f"{environment_name}"},
                            UpdateExpression=f"SET services_task_count[{i}].last_updated = :timestampVal",
                            ExpressionAttributeValues={":timestampVal": timestamp}
                        )
                        print(f"Service {service_name} has been updated with value: {new_desired_value}")
            else:
                print(f"Current desired value of service {service_name} already matches new desired value, not doing anything")

    def update_asg(self, environment_name, resource_name, desired_value):
        timestamp = datetime.now().strftime("%d-%m-%Y %H:%M")
        new_desired_capacity_value = desired_value

        self.table.update_item(
            Key={"environment_name": f"{environment_name}"},
            UpdateExpression=f"SET {resource_name}.desired_value = :asgdesiredVal",
            ExpressionAttributeValues={":asgdesiredVal": int(new_desired_capacity_value)}
        )
        self.table.update_item(
            Key={"environment_name": f"{environment_name}"},
            UpdateExpression=f"SET {resource_name}.last_updated = :timestampVal",
            ExpressionAttributeValues={":timestampVal": timestamp}
        )
        print(f"Success! {resource_name} autoscaling group has been updated successfully with the following desired values: {new_desired_capacity_value}")

    def get_service_desired_from_table(self, environment_name, service_name):
        response = self.table.get_item(Key={"environment_name": f"{environment_name}"})
        item = response["Item"]
        for service in item["services_task_count"]:
            if service["name"] == service_name:
                return int(service["desired_value"])

    def get_service_items(self, environment_name):
        table_items = self.table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["services_task_count"]
        return table_items

    def get_asg_desired_value(self, environment_name, resource_name, action):
        table_items = self.table.get_item(Key={"environment_name": f"{environment_name}"})["Item"][resource_name]
        if table_items["desired_value"] != '':
            current_desired_val = table_items["desired_value"]
            if action == "update-asg":
                return current_desired_val
            elif action == "get-asg":
                print(current_desired_val)
        else:
            print(f'Desired value of resource {resource_name} is empty')

    def get_service(self, environment_name, resource_name):
        table_items = self.table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["services_task_count"]
        for table_item in table_items:
            name = table_item["name"]
            desired_value = table_item["desired_value"]
            last_updated = table_item["last_updated"]
            if name == resource_name:
                print(f"service_name: {name} | desired: {desired_value} | last_updated: {last_updated}")
                return
        print(f"Service {resource_name} cannot be found in the table! exiting")
        sys.exit(1)

    def get_all_services(self, environment_name):
        table_items = self.table.get_item(Key={"environment_name": f"{environment_name}"})["Item"]["services_task_count"]
        for i, table_item in enumerate(table_items):
            name = table_item["name"]
            desired_value = table_item["desired_value"]
            last_updated = table_item["last_updated"]
            print(f"service_name: {name} | desired_value: {desired_value} | last_updated: {last_updated} | table_index: {i}")

class CLIHandler:
    def __init__(self):
        self.parser = argparse.ArgumentParser(description="Updates or reads desired counts of ecs services and protects/unprotects an environment")
        self.parser.add_argument("-e", "--environment-name", help="Environment name")
        self.parser.add_argument("-a", "--action", help="update or get from dynmodb table", required=True)
        self.parser.add_argument("-r", "--resource-name", help="resource name")
        self.parser.add_argument("-d", "--desired-value", help="Value to update")
        self.parser.add_argument("-n", "--aws-account-name", help="processing or commercial")
        self.parser.add_argument("-i", "--issuer-name", help="issuer")
        self.parser.add_argument("-s", "--env-status", help="running (true)/ not running (false)")
        self.parser.add_argument("-t", "--protection-date", help="end protection date")
        self.args = self.parser.parse_args()

    def validate_args(self):
        if self.args.action == 'set-environment-status' and self.args.env_status is None:
            print('Action set-environment-status requires passing true or false')
            sys.exit(1)
        if self.args.action == 'protect' or self.args.action == 'unprotect':
            if self.args.resource_name is not None or self.args.desired_value is not None:
                print("Protecting or unprotecting an environment requires passing only environment name and protection status, exiting.")
                sys.exit(1)
        if str(self.args.action).endswith("-service"):
            if "-" in self.args.resource_name:
                self.args.resource_name = str(self.args.resource_name).replace("-", "_")
        if "get" in self.args.action and self.args.desired_value is not None:
            print(f"Desired value is not required for get actions, exiting.")
            sys.exit(1)
        if "update" in self.args.action and self.args.desired_value is None:
            print("Update action requires passing desired value/s, exiting.")
            sys.exit(1)
        if ("asg" in self.args.action) and (self.args.resource_name is None or self.args.aws_account_name is None):
            print("Please provide autoscaling group name [-r] switch and aws account name [-n], exiting")
            sys.exit(1)
        if self.args.action == "add-issuer" and self.args.issuer_name is None:
            print("Please provide issuer name")
            sys.exit(1)
        if self.args.action == "protect" and self.args.protection_date is None:
            print(f"End protection date not provided! exiting.")
            sys.exit(1)
        elif self.args.action == "protect" and self.args.protection_date is not None:
            self.args.date_value = p.parse(self.args.protection_date, dayfirst=True)
        if self.args.action == "unprotect":
            self.args.date_value = datetime.now()
        if self.args.action == "check-protection":
            self.args.resource_name = None

    def execute_action(self, db_handler):
        if self.args.action == 'get-unprotected-environments' or self.args.action == 'get-protected-environments':
            db_handler.list_environments(self.args.action)
            sys.exit(0)
        if self.args.action == "add-issuer":
            db_handler.add_issuer(self.args.environment_name, self.args.issuer_name)
            sys.exit(0)
        if self.args.action == "check-environment-status":
            db_handler.check_environment_status(self.args.environment_name)
            sys.exit(0)
        if self.args.action == "set-environment-status":
            db_handler.set_environment_status(self.args.environment_name, self.args.env_status)
            sys.exit(0)
        if self.args.action == "protect" or self.args.action == "unprotect":
            db_handler.protect_unprotect_environment(self.args.environment_name, self.args.action, self.args.date_value)
        elif self.args.action == "get-all-services" or self.args.action == "add-environment":
            db_handler.add_environment_to_table(self.args.environment_name)
        else:
            db_handler.update_service(self.args.desired_value, self.args.resource_name, self.args.environment_name)

if __name__ == "__main__":
    cli_handler = CLIHandler()
    cli_handler.validate_args()
    db_handler = DynamoDBHandler('environments_protection')
    cli_handler.execute_action(db_handler)
