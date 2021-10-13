# Code by Itai Ganot 2021

import boto3
import logging

logging.basicConfig(format='%(asctime)s: %(levelname)s - %(message)s')

ecs = boto3.client("ecs")


class CapacityProvider:
    """Initializes a class that handles capacity providers of a given cluster_arn"""
    cluster_arn = ""

    def __init__(self, cluster_arn: str, capacity_provider_name: str):
        self.cluster_arn = cluster_arn
        self.capacity_provider_name = capacity_provider_name
        self.minimal_target_capacity_percent = 50

    @staticmethod
    def cp_check_for_capacity_provider(cluster_arn):
        """Check if a capacity provider is attached to the cluster"""
        try:
            capacity_provider = ecs.describe_clusters(clusters=[cluster_arn])[
                'clusters'][0]['capacityProviders']
        except Exception as e:
            print(f"error: {e}")

        if not capacity_provider:
            return False
        else:
            capacity_provider_name = capacity_provider[0]
            return CapacityProvider(cluster_arn, capacity_provider_name)

    @staticmethod
    def cp_get_capacity_provider_details(capacity_provider_name):
        """Returns capacity provider ARN and current capacity_provider_target_capacity_percent"""
        response = ecs.describe_capacity_providers(
            capacityProviders=[
                capacity_provider_name,
            ],
            include=[
                'TAGS',
            ]
        )['capacityProviders'][0]

        capacity_provider_arn = response['capacityProviderArn']
        capacity_provider_target_capacity_percent = response[
            'autoScalingGroupProvider']['managedScaling']['targetCapacity']

        return capacity_provider_arn, capacity_provider_target_capacity_percent

    @staticmethod
    def cp_add_capacity_provider_tags(capacity_provider_name,
                                      capacity_provider_arn,
                                      capacity_provider_target_capacity_percent
                                      ):
        """Adds a tag with current targetCapacity to capacity provider tags"""
        try:
            ecs.tag_resource(
                resourceArn=capacity_provider_arn,
                tags=[
                    {
                        'key': '{}_targetCapacity'.format(capacity_provider_name),
                        'value': str(capacity_provider_target_capacity_percent)
                    }
                ]
            )
        except Exception as e:
            print(
                f"Unable to tag capacity provider {capacity_provider_name}, error: '{e}'")

        logging.info(
            f"Capacity provider {capacity_provider_name} configuration saved as tag")

    @staticmethod
    def cp_get_saved_capacity_provider_tags(capacity_provider_name):
        """Reads targetCapacity tag from capacity provider"""
        capacity_provider_tags = ecs.describe_capacity_providers(
            capacityProviders=[
                capacity_provider_name,
            ],
            include=[
                'TAGS',
            ]
        )

        for tag in capacity_provider_tags['capacityProviders'][0]['tags']:
            if tag['key'] == '{}_targetCapacity'.format(capacity_provider_name):
                cp_restoredCapacity = tag['value']
                return cp_restoredCapacity
            else:
                continue

    @staticmethod
    def cp_update_capacity_provider(capacity_provider_name, capacity_provider_target_capacity_percent):
        """Updates a capacity provider with target desiredCapacity percent"""
        try:
            ecs.update_capacity_provider(
                name=capacity_provider_name,
                autoScalingGroupProvider={
                    'managedScaling': {
                        'targetCapacity': int(capacity_provider_target_capacity_percent)
                    }
                }
            )
        except Exception as e:
            print(f"Failed updating capacity provider {capacity_provider_name}, reason: "
                  f"'{e}'")

        logging.info(
            f"Capacity provider {capacity_provider_name} has been updated successfully!")

    @staticmethod
    def cp_get_capacity_provider_asg_name(capacity_provider_name):
        response = ecs.describe_capacity_providers(
            capacityProviders=[capacity_provider_name]
        )['capacityProviders'][0]['autoScalingGroupProvider']['autoScalingGroupArn']
        cp_asg_name = str(response).split("/")[1]
        return cp_asg_name

    def start(self):
        """Restores a capacity provider last targetCapacity from capacity provider tag"""
        logging.info(f"Updating capacity provider {self.capacity_provider_name} for cluster "
                     f"{self.cluster_arn} - Starting up")
        self._cp_update_relevant_capacity_provider(self.capacity_provider_name)

    def shutdown(self):
        """Saves capacity provider targetCapacity as tag and sets targetCapacity percent to minimum"""
        current_target_capacity = self.cp_get_capacity_provider_details(
            self.capacity_provider_name)[1]
        if self.minimal_target_capacity_percent == current_target_capacity:
            logging.info(
                f"The right targetCapacity ({current_target_capacity}) is already configured, skipping...")
        else:
            logging.info(f"Updating capacity provider {self.capacity_provider_name} for cluster "
                         f"{self.cluster_arn} - Shutting down")
            self._cp_update_relevant_capacity_provider(self.capacity_provider_name,
                                                       self.minimal_target_capacity_percent)

    def _cp_update_relevant_capacity_provider(self, capacity_provider_name, target_capacity=None):
        """If the action is shutdown, target_capacity of {self.minimal_target_capacity_percent} is passed."""
        capacity_provider_arn, capacity_provider_target_capacity_percent = self.\
            cp_get_capacity_provider_details(capacity_provider_name)
        if target_capacity is None:
            # start action
            capacity_provider_target_capacity_percent = self.cp_get_saved_capacity_provider_tags(
                capacity_provider_name)
            self.cp_update_capacity_provider(
                capacity_provider_name,
                capacity_provider_target_capacity_percent
            )
        else:
            # shutdown action
            self.cp_add_capacity_provider_tags(
                capacity_provider_name,
                capacity_provider_arn,
                capacity_provider_target_capacity_percent
            )
            self.cp_update_capacity_provider(
                capacity_provider_name,
                target_capacity
            )
