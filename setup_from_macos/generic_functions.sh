#!/bin/bash

function ibmcloud_cli_install_check()
{

    if ! command -v ibmcloud &> /dev/null
    then
        echo "IBM Cloud CLI binary could not be found"
        echo "!!!! Please install IBM Cloud CLI !!!!"
    fi

}

function ansible_install_check()
{

    if ! command -v ansible &> /dev/null
    then
        echo "ansible CLI binary could not be found"
        echo "!!!! Please install Ansible Core !!!!"
        echo "ALT: Please install Ansible Community Edition, which includes Ansible Core and default community Ansible Collections"
    fi

}

function ansible_version_check()
{
    ansible_version="$(ansible --version | awk 'NR==1{print $3}' | sed 's/]//g')"

    # Simple resolution to version comparison: https://stackoverflow.com/a/37939589/8412427
    function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

    if [ $(version $ansible_version) -lt $(version "2.11.5") ]; then
        echo "Ansible version is $ansible_version"
        echo "Lower Ansible version than tested, may produce unexpected results"
    fi

}

function input_pretty()
{
    text=$1
    varname=$2

    printf "\n\n"
    echo "----"
    printf "\n"
    echo "$text"
    read -p "Value =  " $varname
    export $varname
    printf "\n"
    echo "####"
}


function input_pretty_confidential()
{
    text=$1
    varname=$2

    printf "\n\n"
    echo "----"
    printf "\n"
    echo "$text"
    read -sp "Value =  " $varname
    export $varname
    printf "\n"
    echo "####"
}
