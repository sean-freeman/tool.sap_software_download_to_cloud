# Dockerfile for preparing a container image with the following contents

# Ubuntu Kinetic / rolling
FROM ubuntu:22.10

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update
RUN apt-get -qq -y install jq curl git
RUN apt-get -qq -y install python3 python3-pip python3-wheel unzip
RUN apt-get -qq -y install python3-urllib3 python3-requests python3-bs4 python3-lxml libxslt1-dev libxml2-dev
RUN apt-get -qq -y install dnsutils

# Use Ansible Core 2.12+ which is available for all Ubuntu versions. Use of Ansible Community Edition locks the Ansible Core at a lower version
RUN apt-get -qq -y install ansible-core

# Downgrade to resolve issues with Ubuntu 22.10, as breaking change in resolvelib was only solved in Ansible Core v2.13.1 - https://github.com/ansible/ansible/blob/stable-2.13/changelogs/CHANGELOG-v2.13.rst#v2131
RUN pip install -Iv 'resolvelib<0.6.0'

RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
RUN ln -s /usr/local/bin/ibmcloud /usr/local/bin/ic
RUN ibmcloud plugin install cloud-object-storage
RUN ibmcloud --version

# Create scripts on root /
WORKDIR /scripts

# Copy from CE /workspace/source into the Docker Container Image /scripts directly
COPY docker_cmd.sh /scripts

# Only one CMD declaration allowed - https://docs.docker.com/engine/reference/builder/#cmd
CMD chmod +x docker_cmd.sh && ./docker_cmd.sh
