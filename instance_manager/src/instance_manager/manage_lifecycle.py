import boto3
from mypy_boto3_ec2 import EC2Client
from mypy_boto3_autoscaling import AutoScalingClient
import argparse
import logging
from concurrent.futures import ThreadPoolExecutor

# Setup logging
logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(message)s",
    level=logging.INFO
)

SERVICES = ["synapse", "sygnal", "coturn-tcp", "coturn-udp", "element", "certbot"]
REGION = "ap-southeast-1"

ec2: EC2Client = boto3.client("ec2", region_name=REGION)
asg: AutoScalingClient = boto3.client("autoscaling", region_name=REGION)

def get_instance_ids(service, prefix, state):
    filters = [
        {"Name": "tag:Name", "Values": [f"{prefix}-{service}*"]},
        {"Name": "instance-state-name", "Values": [state]}
    ]
    response = ec2.describe_instances(Filters=filters)
    ids = [
        i["InstanceId"]
        for r in response["Reservations"]
        for i in r["Instances"]
    ]
    return ids

def get_asg_name(instance_ids):
    response = asg.describe_auto_scaling_instances(InstanceIds=instance_ids)
    return [i["AutoScalingGroupName"] for i in response["AutoScalingInstances"]]

def hibernate_service(service, prefix):
    ids = get_instance_ids(service, prefix, "running")
    if not ids:
        logging.info(f"[{service}] No running instances found.")
        return []

    asgs = get_asg_name(ids)
    for asg_name in asgs:
        asg.enter_standby(
            InstanceIds=ids,
            AutoScalingGroupName=asg_name,
            ShouldDecrementDesiredCapacity=True
        )
        logging.info(f"[{service}] Entered standby: {ids}")

    return ids

def resume_service(service, prefix):
    ids = get_instance_ids(service, prefix, "stopped")
    if not ids:
        logging.info(f"[{service}] No stopped instances found.")
        return []

    ec2.start_instances(InstanceIds=ids)
    logging.info(f"[{service}] Started: {ids}")

    waiter = ec2.get_waiter("instance_running")
    waiter.wait(InstanceIds=ids)

    asgs = get_asg_name(ids)
    for asg_name in asgs:
        asg.exit_standby(
            InstanceIds=ids,
            AutoScalingGroupName=asg_name
        )
        logging.info(f"[{service}] Exited standby: {ids}")

    return ids

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("prefix", help="Environment prefix (e.g. dev)")
    parser.add_argument("mode", choices=["hibernate", "resume"], help="Lifecycle mode")
    args = parser.parse_args()

    all_ids = []

    with ThreadPoolExecutor() as executor:
        futures = []
        for svc in SERVICES:
            if args.mode == "hibernate":
                futures.append(executor.submit(hibernate_service, svc, args.prefix))
            else:
                futures.append(executor.submit(resume_service, svc, args.prefix))

        for f in futures:
            all_ids.extend(f.result())

    if args.mode == "hibernate" and all_ids:
        ec2.stop_instances(InstanceIds=all_ids, Hibernate=True)
        logging.info(f"🛑 Hibernating: {all_ids}")
        waiter = ec2.get_waiter("instance_stopped")
        waiter.wait(InstanceIds=all_ids)
        logging.info("✅ All instances hibernated.")

    elif args.mode == "resume" and all_ids:
        logging.info(f"✅ All instances resumed: {all_ids}")

if __name__ == "__main__":
    main()
