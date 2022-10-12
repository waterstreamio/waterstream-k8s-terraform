# Waterstream Kubernetes Terraform scripts
                                                       
Terraform scripts for deploying Waterstream on Kubernetes cluster.
Doesn't include Kafka setup. If you don't have Kafka yet the simplest way 
is to use [Confluent Cloud](https://confluent.cloud/)

## Pre-requisites

- Terraform installed locally
- Kafka cluster
- DockerHub account credentials - a free one is sufficient
- Waterstream license file. You can request the development license at https://waterstream.io/try-waterstream/

## Kubernetes cluster

### Azure AKS

Full list of authentication methods and how to configure them can be found here: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs. 
Most of the configuration can be done with the environment variables, without changing the scripts directly.
Here we'll briefly recap the approach recommended for running locally - using [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

Log in and check if your credentials work:

    az login
    az account list

If you have multiple subscriptions you can pick the one you'd like to use:

     az account set --subscription="SUBSCRIPTION_ID"

Check the available K8s versions in the region, you'll need it when configuring `kubernetes_version` parameter:

     az aks get-versions --location <your K8s location - e.g. "West Europe">

Now you can go to the `azure_aks` folder, configure and apply the Terraform scripts to have the AKS cluster created for you:

    cd azure_aks
    cp config.auto.tfvars.example config.auto.tfvars
    terraform init # needed only during the first run - to istall TF providers 
    terraform apply --auto-approve

In configuration file `conig.auto.tfvars` you can customize the K8s cluster name, Azure region where it gets deployed,
min and max number of nodes and node type.

Upon successful completion this leaves the `kube_config` file in the `k8-teraform` directory which will then
be used by the Waterstream deploy scripts to authenticate with the Kubernetes.

When not needed you can shut down the Kubernetes cluster:

    terraform destroy --auto-approve

### GCP GKE 

Download `account.json` from GCP Account into `gcp_gke` directory. 
You will have to create a [service account on GCP](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) first if you don't have one.
Once you have a Service Account, you can get `account.json` this way:
- Open GCP Console in the web browser
- Go to "IAM & admin / Service Accounts" section
- Click "Actions / Create Key" for the specific service account, choose JSON key
- Download .json file, rename it to `account.json`
- Copy to the `gcp_gke` directory

Now go to `gcp_gke` folder, customize the config:

    cd gcp_gke 
    cp config.auto.tfvars.example config.auto.tfvars

You'll need to specify GCP project and region. This is and "autopilot" cluster - that is, you don't need
to specify the nodes count and you'll only be charged by GCP for the actual workload running in K8s, 
not the pre-reserved VMs.
And then apply the Terraform scripts to have the GKE cluster created:

    terraform init # needed only during the first run - to istall TF providers 
    terraform apply --auto-approve

Credentials in `kube_config` get expired after 1 hour. If it happens - just run `terraform apply` again to have them refreshed.
When not needed you can shut down GKE cluster:

    terraform destroy --auto-approve

### AWS EKS

You'll need access key and secret key for the AWS user that has permissions to create VPC and EKS cluster. 

Go to the `aws_eks` folder, customize the config:

    cd aws_eks
    cp config.auto.tfvars.example config.auto.tfvars

You'll need to specify at least AWS credentials (`aws_access_key` and `aws_secret_key`) and AWS region.
If you want additional AWS IAM users to be able to see EKS resources in AWS console, add them to the `additional_admins`.
If you're going to deploy multiple Waterstream clusters in the single AWS EKS clusters, each in its own K8s namespace,
be sure to customize `fargate_namespaces` as well - otherwise EKS won't be able to schedule Waterstream pods.

To create the AWS EKS cluser run the terraform scripts:

    terraform init # needed only during the first run - to istall TF providers 
    terraform apply --auto-approve

When the cluster is created it writes `kube_config` file that contains credentials that can be used to deploy
the Waterstream. If credentials get expired - just run `terraform apply` again to refresh them.

When the K8s cluster isn't needed any more you can shut it down:

    terraform destroy --auto-approve

or

    ./destroy_eks.sh

### Use existing K8s cluster

Place Kubernetes config file into `kube_config` in this directory. Then go on to deploying the Waterstream. 

## Create Kafka topics

If you're using Confluent Cloud and you have its CLI installed and configured locally you can create the required topics with this scripts:

    waterstream/createTopicsCCloudMinimal.sh <cluster ID>

or

    waterstream/createTopicsCCloudBig.sh <cluster ID>

You can get the list of the Kafka clusters in Confluet Cloud together with their IDs with `confluent kafka cluster list`.

If you undeploy Waterstream be sure to remove the topics in Confluent Cloud as well:

    waterstream/deleteTopicsCCloud.sh <cluster ID>

If you don't use Confluent Cloud you'll need to create the following topics with your Kafka management tools:

- `mqtt_messages` - that's where MQTT messages get stored. `retention.ms` completely depends on your business needs.
  Number of partitions depends on how much traffic a single Kafka machine in your cluster can sustain and
  on scaling out of third-party tools that are going to read messages from that topic. Typical range is 5 to 50 partitions. 
- `mqtt_sessions` - compacted. To scale out session loading, partitions number should roughly equal number of Waterstream nodes.
- `mqtt_retained_messages` - compacted. 1 partition is enough.
- `mqtt_connections` - short-lived, `retention.ms=60000` is enough. 1 partition is enough.
- `__waterstream_heartbeat` - short-lived, `retention.ms=60000` is enough. 1 partition is enough.

## Deploy Waterstream

Make sure you have the license file `waterstream.license` in the `waterstream` folder. 

Once you have created Kubernetes cluster with one of the methods described above and you have `kube_config` file in this
folder you can deploy Waterstream.
Go to the `waterstream` folder, copy the example variables file and edit it:

    cd waterstream
    cp config.auto.tfvars.example config.auto.tfvars

Mandatory parameters to configure are DockerHub credentials and Kafka connection options.
You can also customize the Waterstream version, node size and nodes count.

If you want to have multiple Waterstream deployments on single K8s cluster be sure to customize the `namespaces_suffix`
so that they would be deployed to the separate namespaces.

Run the scripts:

    terraform init
    terraform apply --auto-approve

## Monitoring

To forward Grafana ports to the local machine you'll need `kubectl`:

    kubectl --kubeconfig kube_config port-forward -n waterstream-monitoring service/grafana 3000:3000

After that you'll be able to open http://localhost:3000 in your browser and find the Waterstream dashboard.
Default credentials are `admin/admin`, you'll be prompted to change it when you open Grafana for the first time.

If you also want to see the Prometheus UI - you can forward Prometheus ports to the local machine: 

    kubectl --kubeconfig kube_config port-forward -n waterstream-monitoring service/prometheus 9090:9090 

## Useful commands

List Waterstream pods:

    kubectl --kubeconfig kube_config get pod --namespace waterstream

Get specific pod logs:

    kubectl --kubeconfig kube_config logs <pod name> --namespace waterstream


## Undeploy

In `waterstream` folder:

    terraform destroy --auto-approve

If you're using Confluent Cloud be sure to remove the topics: 

    ./deleteTopicsCCloud.sh <cluster ID>

## Current limitations of these scripts

Some features supported by Waterstream aren't yet covered by these scripts, they need customizations:

- Authentication/authorization 
- SSL for MQTT connections 
- MQTT over WebSocket
