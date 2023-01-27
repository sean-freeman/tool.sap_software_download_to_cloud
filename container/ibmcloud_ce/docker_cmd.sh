#!/bin/sh

echo 'Running shell script file'

# Wait until connectivity
while ! curl -fs ibm.com ; do true ; done

# Retrieve latest Ansible Playbook and Extravars file with SAP Software Installation Media file updates
# Clone repository into the Docker Container Image work directory
git clone https://github.com/sean-freeman/tool.sap_software_download_to_cloud


# DEBUG: Capture Start Time
#DATEISO=$(date '+%Y-%m-%d')

# DEBUG: Run env to show custom environment variables provided in the IBM Cloud Code Engine Job definition
#env

# DEBUG: Show container workdir contents
#ls -lha ./
#pwd

# The default environment variables are:
#echo $CE_DOMAIN
#echo $CE_JOB
#echo $CE_JOBRUN
#echo $CE_SUBDOMAIN

# Expected custom environment variables, set by the Job Image secrets:
# IBMCLOUD_SERVICE_ID_APIKEY_CE_TO_CR
# IBMCLOUD_SERVICE_ID_APIKEY_COS_OPERATOR

# Expected custom environment variables, set by the specific Job Run instantiation environment variables given:
# ANSBILE_IBMCLOUD_BUCKET
# ANSBILE_SAP_DOWNLOADS_SELECTED
# ANSBILE_SAP_DOWNLOADS_CPU_ARCHITECTURE
# ANSBILE_SAP_SUSER
# ANSBILE_SAP_SUSER_PASSWORD


# Begin Ansible execution

ansible-galaxy collection install --requirements-file ./tool.sap_software_download_to_cloud/container/ansible_playbook/ansible_requirements_collections.yml

ansible-playbook --timeout 60 \
./tool.sap_software_download_to_cloud/container/ansible_playbook/ansible_playbook.yml \
--inventory 'localhost,' \
--connection 'local' \
--extra-vars "@./tool.sap_software_download_to_cloud/container/ansible_playbook/ansible_vars.yml"
