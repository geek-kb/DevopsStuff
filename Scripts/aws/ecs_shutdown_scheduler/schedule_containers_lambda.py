import logging
import os
import boto3
import ECSService
import EC2Service
import CapacityProvider

logging.basicConfig(format='%(asctime)s: %(levelname)s - %(message)s')
logging.getLogger().setLevel(os.environ.get("LOG_LEVEL", "INFO"))

ecs = boto3.client("ecs")

def whitelisted(cluster_arn: str):
    """
    Determines whether or not a service is whitelisted for this scheduler
    """
    override = ECSService.ECSService.svc_get_override_ecs_cluster_tag(cluster_arn)
    if override:
        return True
    else:
        return False


#def main():
def lambda_handler(event, _context):
    try:
        clusters = ecs.list_clusters()
    except Exception as e:
        print(f"No clusters found!"
              f"error: {e}")
        exit(1)

    for cluster_arn in clusters["clusterArns"]:

        if whitelisted(cluster_arn):
            """Check if cluster is whitelisted"""
            continue

        capacity_provider_configured = CapacityProvider.CapacityProvider.cp_check_for_capacity_provider(cluster_arn)
        # list each service for ecs clusters
        cluster_services = ecs.list_services(cluster=cluster_arn)['serviceArns']
        task = event.get("Task", "")
        #task = "shutdown"
        cluster_name = str(cluster_arn).split("/")[1]
        logging.info(f"Now handling cluster {cluster_name}...")
        if task == "shutdown":
            if capacity_provider_configured:
                """Check if a capacity provider is attached to the cluster"""
                capacity_provider_name = vars(capacity_provider_configured)['capacity_provider_name']
                cp_asg_name = capacity_provider_configured.cp_get_capacity_provider_asg_name(capacity_provider_name)

                instance_asg_names = ECSService.ECSService.get_asg_names_from_instance_tag(cluster_arn)
                for asg_name in instance_asg_names:
                    if asg_name != cp_asg_name:
                        non_cp_asg_name = asg_name
                        asg_service = EC2Service.ASGService.load_from_cluster_arn(cluster_arn, non_cp_asg_name)
                        asg_service.shutdown()
                    else:
                        logging.info(f"AutoScaling group '{asg_name}' is attached to capacity provider "
                              f"'{capacity_provider_name}', skipping...")
                        continue
                CapacityProvider.CapacityProvider.shutdown(capacity_provider_configured)
            else:
                if cluster_services:
                    """Check for services in cluster"""
                    for service_arn in cluster_services:
                        logging.info(f"Now handling service {service_arn} from cluster {cluster_arn}")
                        ecs_service = ECSService.ECSService(cluster_arn, service_arn)
                        ecs_service.shutdown()
                else:
                    logging.info(f"Cluster {cluster_name} has no services to shutdown")
                    continue
        elif task == "start":
            if capacity_provider_configured:
                """Check if a capacity provider is attached to the cluster"""
                capacity_provider_name = vars(capacity_provider_configured)['capacity_provider_name']
                cp_asg_name = capacity_provider_configured.cp_get_capacity_provider_asg_name(capacity_provider_name)
                instance_asg_names = ECSService.ECSService.get_asg_names_from_instance_tag(cluster_arn)
                for asg_name in instance_asg_names:
                    if asg_name != cp_asg_name:
                        non_cp_asg_name = asg_name
                        asg_service = EC2Service.ASGService.load_from_cluster_arn(cluster_arn, non_cp_asg_name)
                        asg_service.start()
                    else:
                        logging.info(f"AutoScaling group '{asg_name}' is attached to capacity provider "
                              f"'{capacity_provider_name}', skipping...")
                        continue
                CapacityProvider.CapacityProvider.start(capacity_provider_configured)
            else:
                logging.info('no capacity providers configured')
                if cluster_services:
                    """Check for services in cluster"""
                    for service_arn in cluster_services:
                        logging.info(f"Now handling service {service_arn} from cluster {cluster_arn}")
                        ecs_service = ECSService.ECSService(cluster_arn, service_arn)
                        ecs_service.start()
                else:
                    logging.info(f"Cluster {cluster_name} has no services to start")
                    continue
        else:
            raise (
                f"Couldn't interpret TASK: {task}. Must be one of: shutdown, start. Exiting"
            )

