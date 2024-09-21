#!/bin/bash

##
# rancher-mgr.sh
#
# Utility functions:
#   usage()         - prints usage
#   log_out()       - logs error message to STDOUT
#   log_err()       - wrapper function calling log_out with "err" and $1
#   log_info()      - wrapper function calling log_out with "info" and $1
#   log_success()   - wrapper function calling log_out with "success" and $1
#   
#
# Primary functions:
#   create_cluster() - creates cluster and outputs kubectl command needed to register
#
# TODO:
#   - support long options
#   - support base_url long option
##

##
# Logging
##
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log_out() {
    case $1 in 
        "err")
            echo -e "${RED}[Error]${NC} ${2}";
            exit 1;
        ;;
        "info")
             echo -e "${BLUE}[INFO]${NC} ${2}";
        ;;
        "success")
             echo -e "${GREEN}[SUCCESS]${NC} ${2}";
        ;;
    esac
}
log_err(){
    log_out "err" "$1"
}
log_info(){
    log_out "info" "$1"
}
log_success(){
    log_out "success" "$1"
}

##
# Preflight checks
##
# Check if curl is installed
if ! command -v curl &> /dev/null; then
    on_err "Error: curl is not installed."
    exit 1
fi

##
# Constants
##
RANCHER_URL="https://rancher.domain.net"

##
# rancher-mgr.sh
##
usage(){
    echo "Usage: $0 [-c <string>] [-r <string>]"
    echo
    echo "  Expects RANCHER_ACCESS_KEY and RANCHER_SECRET_KEY to"
    echo "  be set as environment variables"
    echo
    echo "  Options:"
    echo "      -c      Create cluster with given name. String."
    echo 
    exit 1
}

# Function create_cluster
# Description: 
#   Makes a POST request to rancher_url/v3/clusters
# Arguments:
#   $1 - rancher url
#   $2 - cluster name
# Output:
#   Kubectl command to be ran in cluster to register
create_cluster(){
    local cluster_exists=false
    local response_body=""
    local cluster_id=""

    # Check if cluster already exists
    response_body=$(curl -s -u "${RANCHER_ACCESS_KEY}:${RANCHER_SECRET_KEY}" \
        -X GET \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        "${1}/v3/clusters?name=$2")
    cluster_id=$(echo "${response_body}" | jq ".data[0].id" | tr -d '"')
    if [ $cluster_id != "null" ]; then
        log_info "Cluster already exists with id ${cluster_id}, skipping cluster creation"
        cluster_exists=true
    else
        log_info "Cluster id is $cluster_id, will create cluster"
    fi

    # Create cluster if it does not exists
    # TODO check response code
    if [ "${cluster_exists}" == "false" ]; then
        response_body=$(curl -s -u "${RANCHER_ACCESS_KEY}:${RANCHER_SECRET_KEY}" \
        -X POST \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -d "{\"name\":\"$2\"}" \
        "${1}/v3/clusters")
        cluster_id=$(echo "${response_body}" | jq ".id" | tr -d '"')
        log_info "Cluster created with id: ${cluster_id}."
        log_info "Sleeping for 3 seconds to allow clusterregistrationtoken to populate with valid data"
        sleep 3
    fi
    
    # Get Registration command
    registration_command=$(curl -s -u "${RANCHER_ACCESS_KEY}:${RANCHER_SECRET_KEY}" \
        -X GET \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        "${1}/v3/clusters/${cluster_id}/clusterregistrationtokens" \
        | jq ".data[0].command")
    log_success "Register with command: ${registration_command}" 
}

while getopts "c:r:" opt; do
    case "${opt}" in
        c)
            opt_cluster_name=${OPTARG}
            create_cluster "$RANCHER_URL" "$opt_cluster_name"
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$opt_cluster_name" ]; then
    log_err "Missing required argument -c"
    usage
fi
if [ -z "$RANCHER_ACCESS_KEY" ]; then
    log_err "Missing RANCHER_ACCESS_KEY. Set this as an environment variable"
    echo "    example: export \$RANCHER_ACCESS_KEY=your-access-key"
    echo
    usage
fi
if [ -z "$RANCHER_SECRET_KEY" ]; then
    log_err "Missing RANCHER_SECRET_KEY. Set this as an environment variable"
    echo "  example: export \$RANCHER_SECRET_KEY=your-access-key"
    echo
    usage
fi
