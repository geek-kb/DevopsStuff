# Code by Itai Ganot 2021

import re
import boto3
import logging

logging.basicConfig(format='%(asctime)s: %(levelname)s - %(message)s')

ecs = boto3.client("ecs")
ec2 = boto3.client("ec2")


class ECSService:
    """Initializes a class that returns information about clusters and their services"""
    cluster_arn = ""
    ecs_cluster_id = ""
    service_arn = ""
    ecs_service_name = ""
    ecs_launch_type = ""
    desired_count_from_service = ""

    def __init__(self, cluster_arn: str, service_arn: str):
        self.cluster_arn = cluster_arn
        self.ecs_cluster_id = re.match(
            r"arn:aws:ecs:.+:cluster\/(.+)", cluster_arn).group(1)
        self.service_arn = service_arn
        if re.match(r"arn:aws:ecs:.+:service\/.+\/(.+)", service_arn) is not None:
            self.ecs_service_name = re.match(
                r"arn:aws:ecs:.+:service\/.+\/(.+)", service_arn).group(1)
        else:
            self.ecs_service_name = re.match(
                r"arn:aws:ecs:.+:service\/(.+)", service_arn).group(1)
        self.minimal_desired_count = 0

    def start(self):
        """Restores services desired count to last desiredCount from service tags"""
        desired_count_from_service = self._svc_get_desired_count_ecs_service_tag()
        if not desired_count_from_service:
            desired_count_from_service = self.minimal_desired_count
        self._svc_set_desired_count(desired_count_from_service)

    def shutdown(self):
        """Saves service's desiredCapacity as service tag and sets capacity to {self.minimal_desired_count}"""
        service_status = ecs.describe_services(
            cluster=self.cluster_arn, services=[self.ecs_service_name])
        desired_count = service_status["services"][0]["desiredCount"]

        if not desired_count or desired_count == 0:
            logging.info(
                f"Service {self.ecs_service_name} is already shutdown. Nothing to do. Skipping...")
            return

        self._svc_shutdown(desired_count)

    def _svc_adds_service_desired_capacity_to_service_tags(self, desired_count: int):
        """Adds a desired count to a service tag"""
        ecs.tag_resource(
            resourceArn=self.service_arn,
            tags=[
                {
                    'key': '{}_desiredCapacity'.format(self.ecs_service_name),
                    'value': str(desired_count)
                }
            ]
        )
        logging.info("Added tag containing current desiredCount to service")

    def _svc_shutdown(self, desired_count: int):
        """Saves service desired capaciy as service tags and updates current desired count accordingly"""
        self._svc_adds_service_desired_capacity_to_service_tags(desired_count)
        self._svc_set_desired_count(0)

    def _svc_set_desired_count(self, desired_count: int):
        """Updates the desired count of a given service"""
        try:
            ecs.update_service(cluster=self.cluster_arn,
                               service=self.ecs_service_name,
                               desiredCount=desired_count)
        except Exception as e:
            logging.error(f"Unable to set desired count {desired_count} for"
                          f" service '{self.ecs_cluster_id}/{self.ecs_service_name}'"
                          f"Error: {e}")

        logging.info(f"ECS service '{self.ecs_cluster_id}/{self.ecs_service_name}' desired capacity "
                     f"has been set to {desired_count}")

    def _svc_get_desired_count_ecs_service_tag(self):
        """Gets desired count from an ecs service tag (required for start process)"""
        desired_count_tag = ''
        response = ecs.describe_services(
            cluster=self.cluster_arn,
            services=[
                self.ecs_service_name,
            ],
            include=[
                'TAGS',
            ]
        )['services'][0]

        if 'tags' in response:
            for pair in response['tags']:
                if pair['key'] == self.ecs_service_name + '_desiredCapacity':
                    desired_count_tag = pair['value']

            if len(desired_count_tag) > 0:
                return int(desired_count_tag)
            else:
                logging.info(
                    f"Unable to find last desired count for service {self.ecs_service_name}, setting 0")
                return False

    @staticmethod
    def get_asg_names_from_instance_tag(cluster_arn):
        container_instances = ecs.list_container_instances(
            cluster=cluster_arn)['containerInstanceArns']
        asg_names_list = []
        if container_instances:
            for container_instance_arn in container_instances:
                instance_id = ecs.describe_container_instances(
                    cluster=cluster_arn,
                    containerInstances=[container_instance_arn]
                )['containerInstances'][0]['ec2InstanceId']
                instance_tags = ec2.describe_instances(
                    InstanceIds=[instance_id]
                )['Reservations'][0]['Instances'][0]['Tags']
                for tag in instance_tags:
                    if tag['Key'] == 'aws:autoscaling:groupName':
                        asg_name = tag['Value']
                        asg_names_list.append(asg_name)
        asg_names_list = list(set(asg_names_list))
        return asg_names_list

    @staticmethod
    def svc_get_override_ecs_cluster_tag(cluster_arn):
        """Checks if a cluster is whitelisted"""
        cluster_name = str(cluster_arn).split("/")[1]
        override = ''
        try:
            response = ecs.describe_clusters(
                clusters=[
                    cluster_arn
                ],
                include=[
                    'TAGS'
                ]
            )
        except Exception as e:
            print(f"error: {e}")

        for pair in response['clusters'][0]['tags']:
            if pair['key'] == 'Override':
                override = pair['value']

        if override == 'True':
            logging.info(
                f"Cluster {cluster_name} is marked as overridden, skipping...")
            return True
        else:
            return False
