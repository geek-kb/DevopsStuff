# Code by Itai Ganot 2021

import re
import boto3
import logging

logging.basicConfig(format='%(asctime)s: %(levelname)s - %(message)s')

autoscaling = boto3.client("autoscaling")
ecs = boto3.client("ecs")


class ASGService:
    def __init__(self, cluster_arn: str, asg_name: str):
        self.cluster_arn = cluster_arn
        self.asg_name = asg_name

    @property
    def ecs_cluster_id(self):
        return re.match(r"arn:aws:ecs:.+:cluster\/(.+)", self.cluster_arn).group(1)

    @staticmethod
    def load_from_cluster_arn(cluster_arn, asg_name=None):
        if asg_name:
            return ASGService(cluster_arn, asg_name)
        return None

    def _asg_current_get_desired_and_minimum(self):
        asg_info = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[self.asg_name])['AutoScalingGroups'][0]
        asg_desired = asg_info['DesiredCapacity']
        asg_min = asg_info['MinSize']
        return asg_min, asg_desired

    def _asg_get_desired_and_minimum_from_tags(self):
        try:
            asg_info = autoscaling.describe_auto_scaling_groups(
                AutoScalingGroupNames=[self.asg_name])['AutoScalingGroups'][0]['Tags']
        except Exception as e:
            print(
                f"Unable to describe AutoScaling group {self.asg_name}, error: {e}")

        if asg_info:
            for tag in asg_info:
                if tag['Key'] == 'ASG Minimum Capacity':
                    asg_min = tag['Value']
                if tag['Key'] == 'ASG Desired Capacity':
                    asg_desired = tag['Value']

        return int(asg_min), int(asg_desired)

    def start(self):
        """ Start the service based on the original parameters from the asg tags"""
        asg_name = self.asg_name

        asg_min, asg_desired = self._asg_get_desired_and_minimum_from_tags()
        self._asg_set_desired_count(asg_desired, asg_min)

        logging.info(
            f"'{self.ecs_cluster_id}/{asg_name}' Configuration from autoscaling group has been restored."
        )

    def shutdown(self):
        asg_name = self.asg_name

        asg_min, asg_desired = self._asg_current_get_desired_and_minimum()

        if not asg_desired:
            logging.info(
                f"DesiredCapacity of autoscaling group {asg_name} is already 0. Nothing to do. Skipping...")
            return

        self._asg_add_tag_with_desired(asg_name, asg_min, asg_desired)
        self._asg_set_desired_count(0)

    def _asg_set_desired_count(self, asg_desired: int, asg_min=None):
        if asg_min is None:
            """ Check if asg_min was provided (if shutdown)"""
            try:
                autoscaling.update_auto_scaling_group(AutoScalingGroupName=self.asg_name,
                                                      MinSize=asg_desired,
                                                      DesiredCapacity=asg_desired)
            except Exception as e:
                print(f"error: '{e}'")
            logging.info(f"Autoscaling group '{self.ecs_cluster_id}/{self.asg_name}' desired capacity has "
                         f"been updated to: {asg_desired}")
        else:
            try:
                autoscaling.update_auto_scaling_group(AutoScalingGroupName=self.asg_name,
                                                      MinSize=asg_min,
                                                      DesiredCapacity=asg_desired)
            except Exception as e:
                print(f"error: '{e}'")
            logging.info(f"Autoscaling group '{self.ecs_cluster_id}/{self.asg_name}'"
                         f"desired capacity restored to {asg_desired}")

    def _asg_add_tag_with_desired(self, asg_name, asg_min, asg_desired):
        """ Saves given parameters as an ssm parameter
        """
        try:
            autoscaling.create_or_update_tags(
                Tags=[
                    {
                        'ResourceId': asg_name,
                        'ResourceType': 'auto-scaling-group',
                        'Key': 'ASG Minimum Capacity',
                        'Value': str(asg_min),
                        'PropagateAtLaunch': False
                    },
                    {
                        'ResourceId': asg_name,
                        'ResourceType': 'auto-scaling-group',
                        'Key': 'ASG Desired Capacity',
                        'Value': str(asg_desired),
                        'PropagateAtLaunch': False
                    }
                ]
            )
        except Exception as e:
            print(f"error: '{e}'")

        logging.info(
            f"Backed up Min and Desired counts as tags on autoscaling group {asg_name}")
