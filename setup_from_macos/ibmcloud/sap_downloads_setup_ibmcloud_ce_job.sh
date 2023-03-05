#!/bin/sh

. ./setup_from_macos/generic_functions.sh

# Main

ibmcloud_cli_install_check
ansible_install_check
ansible_version_check


input_pretty_confidential "Please enter your IBM Cloud API Key" ibmcloud_apikey
input_pretty "Please enter the IBM Cloud region to instantiate IBM Cloud Code Engine" ibmcloud_region
input_pretty "Please enter the Resource Group for the resources created with and run by IBM Cloud Code Engine" ibmcloud_resource_group
input_pretty "Please enter the target IBM Cloud Object Storage Bucket name where the SAP Software installation media will be downloaded to" ANSIBLE_IBMCLOUD_BUCKET
input_pretty "Please enter the CPU Architecture of the SAP Software installation media to download (options are x86_64, ppc64le)" ANSIBLE_SAP_DOWNLOADS_CPU_ARCHITECTURE
input_pretty "Please enter which SAP Software installation media to download. Please select from options (separate with comma - for example sap_s4hana_2022,sap_ecc6_ehp6_hana):
sap_s4hana_2022
sap_s4hana_2021
sap_bw4hana_2021
sap_ecc6_ehp8_hana
sap_ecc6_ehp8_ibmdb2
sap_ecc6_ehp8_oracledb
sap_ecc6_ehp8_sapase
sap_ecc6_ehp8_sapmaxdb
sap_ecc6_ehp7_hana
sap_ecc6_ehp7_ibmdb2
sap_ides_ecc6_ehp8_hana
sap_ides_ecc6_ehp8_ibmdb2
sap_ides_ecc6_ehp8_oracledb
sap_ides_ecc6_ehp8_sapase
sap_ides_ecc6_ehp8_sapmaxdb
sap_nwas_750_sp22_java_ibmdb2_ads
sap_nwas_750_sp22_java_sapase_ads
sap_nwas_750_sp00_abap_hana
sap_nwas_750_sp00_abap_ibmdb2
sap_nwas_750_sp00_abap_oracledb
sap_nwas_750_sp00_abap_sapase
sap_nwas_750_sp00_abap_sapmaxdb
sap_nwas_752_sp00_abap_hana
sap_nwas_752_sp00_abap_ibmdb2
sap_nwas_752_sp00_abap_oracledb
sap_nwas_752_sp00_abap_sapase
sap_nwas_752_sp00_abap_sapmaxdb" ANSIBLE_SAP_DOWNLOADS_SELECTED
input_pretty "Please enter your SAP User ID" ANSIBLE_SAP_SUSER
input_pretty_confidential "Please enter your SAP User ID Password" ANSIBLE_SAP_SUSER_PASSWORD
input_pretty "Please enter the name of the IBM Cloud Code Engine instance and resources (e.g. sap-downloads)" CE_PROJECT_NAME

# Declare manually for testing, comment-out above input prompts
#ibmcloud_apikey=""
#ibmcloud_region=""
#ibmcloud_resource_group=""
#ANSIBLE_IBMCLOUD_BUCKET=""
#ANSIBLE_SAP_DOWNLOADS_CPU_ARCHITECTURE=""
#ANSIBLE_SAP_DOWNLOADS_SELECTED=""
#ANSIBLE_SAP_SUSER=""
#ANSIBLE_SAP_SUSER_PASSWORD=""
#CE_PROJECT_NAME=""


# Standard variables
CE_DOCKER_IMAGE_NAME="$CE_PROJECT_NAME-ce-image"


# Login and assign region to IBM Cloud CLI
ibmcloud config --check-version=false
ibmcloud login --apikey="$ibmcloud_apikey" --no-region
ibmcloud config --check-version=true
ibmcloud target -r $ibmcloud_region

# Ensure IBM Cloud CLI plugins are installed
ibmcloud_cli_plugins=$(ibmcloud plugin list | awk '{print $1}')
if grep -q 'code-engine' <<<"$ibmcloud_cli_plugins"; then echo "Skipping code-engine plugin install to IBM Cloud CLI"; else ibmcloud plugin install -f code-engine; fi
if grep -q 'container-registry' <<<"$ibmcloud_cli_plugins"; then echo "Skipping container-registry plugin install to IBM Cloud CLI"; else ibmcloud plugin install -f container-registry; fi

# Target an existing Resource Group
ibmcloud target -g "$ibmcloud_resource_group"

# Create IBM Cloud Container Registry namespace
ibmcloud cr namespace-add "$CE_PROJECT_NAME-cr-for-ce"

# Get IBM Cloud Container Registry URL subdomain
ibmcloud_cr_subdomain=$(ibmcloud cr info | grep 'Container Registry' | grep -v 'https' | awk '{print $3}')

# Create IBM Cloud Code Engine project
ibmcloud ce project create \
--name "$CE_PROJECT_NAME-ce" \
--endpoint 'public'

# Create IBM Cloud IAM Service ID
ibmcloud iam service-id-create "service-id-$CE_PROJECT_NAME-ce-to-cr" \
--description "Service ID for Project $CE_PROJECT_NAME IBM Cloud Code Engine to IBM Cloud Container Registry"

# Edit IBM Cloud IAM Service ID with Manager access to Container Registry
ibmcloud iam service-policy-create "service-id-$CE_PROJECT_NAME-ce-to-cr" \
--roles 'Manager' \
--service-name 'container-registry' \
--resource-group-name "$ibmcloud_resource_group"

# Create API Key for IBM Cloud IAM Service ID
service_id_api_key_ce_to_cr=$(ibmcloud iam service-api-key-create "service-id-$CE_PROJECT_NAME-apikey-ce-to-cr" "service-id-$CE_PROJECT_NAME-ce-to-cr" --output json | jq -r .apikey)

# Create IBM Cloud IAM Service ID
ibmcloud iam service-id-create "service-id-$CE_PROJECT_NAME-cos-operator" \
--description "Service ID for Project $CE_PROJECT_NAME IBM Cloud Code Engine to IBM Cloud Object Storage"

# Edit IBM Cloud IAM Service ID with operator and manager (upload) access to IBM Cloud Object Storage
ibmcloud iam service-policy-create "service-id-$CE_PROJECT_NAME-cos-operator" \
--roles 'Operator,Manager' \
--service-name 'cloud-object-storage'

# Edit IBM Cloud IAM Service ID with viewer access of all Resource Groups
ibmcloud iam service-policy-create "service-id-$CE_PROJECT_NAME-cos-operator" \
--roles 'Viewer' \
--resource-type=resource-group

# Create API Key for IBM Cloud IAM Service ID
service_id_api_key_cos_operator=$(ibmcloud iam service-api-key-create "service-id-$CE_PROJECT_NAME-apikey-cos-operator" "service-id-$CE_PROJECT_NAME-cos-operator" --output json | jq -r .apikey)


# Create IBM Cloud Code Engine connection to custom git repository, using SSH Keyfile
#ibmcloud ce repo create \
#--name 'custom-git-connection' \
#--host github.custom-domain.com \
#--key-path "$key_file_path"

# Create IBM Cloud Code Engine access to IBM Cloud Container Registry in current region
ibmcloud ce registry create \
--name "$CE_PROJECT_NAME-ce-access-to-cr" \
--username 'iamapikey' \
--password "$service_id_api_key_ce_to_cr" \
--server "$ibmcloud_cr_subdomain"

# Create IBM Cloud Code Engine build image definition
ibmcloud ce build create \
--name "$CE_PROJECT_NAME-ce-build-image" \
--image "$ibmcloud_cr_subdomain/$CE_PROJECT_NAME-cr-for-ce/$CE_DOCKER_IMAGE_NAME" \
--registry-secret "$CE_PROJECT_NAME-ce-access-to-cr" \
--strategy dockerfile \
--size medium \
--build-type git \
--context-dir "/container/ibmcloud_ce" \
--source https://github.com/sean-freeman/tool.sap_software_download_to_cloud \
--commit main
#--source git@github.custom-domain.com:org/repo.git \
#--commit main \
#--git-repo-secret 'custom-git-connection'

# Show IBM Cloud Code Engine build image definition details
ibmcloud ce build get \
--name "$CE_PROJECT_NAME-ce-build-image"

# Create IBM Cloud Code Engine build image run (i.e. generate the container image)
ibmcloud ce buildrun submit \
--build "$CE_PROJECT_NAME-ce-build-image" \
--image "$ibmcloud_cr_subdomain/$CE_PROJECT_NAME-cr-for-ce/$CE_DOCKER_IMAGE_NAME"

# Find latest build image run (i.e. generate the container image)
CE_CONTAINER_LATEST=$(ibmcloud ce buildrun list --sort-by age | grep "$CE_PROJECT_NAME-ce-build-image" | awk 'FNR == 1 {print $1}')

# Show IBM Cloud Code Engine build image run (generate the container image) details
ibmcloud ce buildrun get \
--name "$CE_CONTAINER_LATEST"


# Create IBM Cloud Code Engine secret to hold IBM Cloud IAM Service ID API Key
ibmcloud ce secret create \
--name "$CE_PROJECT_NAME-ce-job-secrets-ibmcos" \
--from-literal IBMCLOUD_SERVICE_ID_APIKEY_CE_TO_CR=$service_id_api_key_ce_to_cr \
--from-literal IBMCLOUD_SERVICE_ID_APIKEY_COS_OPERATOR=$service_id_api_key_cos_operator

# Create IBM Cloud Code Engine secret to hold SAP User ID credentials
ibmcloud ce secret create \
--name "$CE_PROJECT_NAME-ce-job-secrets-suser" \
--from-literal ANSIBLE_SAP_SUSER=$ANSIBLE_SAP_SUSER \
--from-literal ANSIBLE_SAP_SUSER_PASSWORD=$ANSIBLE_SAP_SUSER_PASSWORD

# Create IBM Cloud Code Engine Job definition, using the build image
# Use 10,800 seconds (i.e. 3 hours) as execution time maximum
# Use --wait until the Container Image is generated
ibmcloud ce job create \
--name "$CE_PROJECT_NAME-ce-job" \
--image "$ibmcloud_cr_subdomain/$CE_PROJECT_NAME-cr-for-ce/$CE_DOCKER_IMAGE_NAME" \
--registry-secret "$CE_PROJECT_NAME-ce-access-to-cr" \
--service-account 'manager' \
--env-from-secret "$CE_PROJECT_NAME-ce-job-secrets-ibmcos" \
--env-from-secret "$CE_PROJECT_NAME-ce-job-secrets-suser" \
--retrylimit "1" \
--maxexecutiontime "10800" \
--instances 1 \
--cpu 2 \
--memory 8G \
--ephemeral-storage 8G # Cannot exceed quantity of Memory GB, therefore maximum file which can be downloaded is 8GB
# --env test1=A

## Operators:
####--command '/bin/sh' \
####--argument "-c 'ls -lha'" \
## Create Errors:
####  /bin/sh: illegal option -



# Create job run instance of IBM Cloud Code Engine Job using the build image (generated container image)
# Add environment variables to pass into the Ansible Playbook, allowing re-use of the existing Job to download SAP Software repeatably
ibmcloud ce jobrun submit \
--name "$CE_PROJECT_NAME-ce-jobrun" \
--job "$CE_PROJECT_NAME-ce-job" \
--env ANSIBLE_IBMCLOUD_BUCKET=\'$ANSIBLE_IBMCLOUD_BUCKET\' \
--env ANSIBLE_SAP_DOWNLOADS_SELECTED=\'$ANSIBLE_SAP_DOWNLOADS_SELECTED\' \
--env ANSIBLE_SAP_DOWNLOADS_CPU_ARCHITECTURE=\'$ANSIBLE_SAP_DOWNLOADS_CPU_ARCHITECTURE\'

# Show IBM Cloud Code Engine job run instance details
ibmcloud ce jobrun get --name "$CE_PROJECT_NAME-ce-jobrun"



# OPTIONAL: Once downloaded, delete all IBM Cloud Code Engine resources
#ibmcloud iam service-id-delete --force "service-id-$CE_PROJECT_NAME-ce-to-cr"
#ibmcloud iam service-id-delete --force "service-id-$CE_PROJECT_NAME-cos-operator"
#ibmcloud cr namespace-rm --force "$CE_PROJECT_NAME-cr-for-ce"
#ibmcloud ce project delete --hard --force --name "$CE_PROJECT_NAME-ce"


# DEBUG: container system events of the job run instance
#ibmcloud ce jobrun events --name "$CE_PROJECT_NAME-ce-jobrun"

# DEBUG: logs of the job run instance
#ibmcloud ce jobrun logs --follow --name "$CE_PROJECT_NAME-ce-jobrun"
