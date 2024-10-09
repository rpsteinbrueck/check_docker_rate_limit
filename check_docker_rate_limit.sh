#!/bin/bash
#set -x

SCRIPT_VERSION=0.0.1

##################################
# HELP
##################################
function help () {
   echo "check_docker_rate_limit.sh ${SCRIPT_VERSION}
Written by rpsteinbrueck.

This check was written to monitor the Docker Hub rate limit status.
Docker Hub throttles container Image pulling and data storage uploading for fair use of their service.

This check was built on the commands which Docker Hub describe in their own documentation found under:
https://docs.docker.com/docker-hub/download-rate-limit/#how-can-i-check-my-current-rate

It then determines how much the Docker Hub rate limit capacity is in percentage.
- 0% being no images have been pulled within the rate limit window.
- 100% being rate limit has been reached.
- Default threshold values:
  - warning 80%
  - critical 90%

***This rate limit also applies to other requests being made to Docker Hub not just image pulls.

This check then outputs a status on how many images have been pulled with typical monitoring exit code.
exit 0 - OK
exit 1 - WARNING
exit 2 - CRITICAL
exit 3 - UNKNOWN

*Storing secret as a file on the system.
When using the arguement -s/--secret_file, the secret must look like <user>:<password> and be base64 encoded.
(base64 does not mean secret is encrypted it is just encoded)

Example for creating the secret:
    echo <user>:<password> | base64
    echo <user>:<password> | base64 > <secret_file_location>

Syntax: check_docker_hub_rate_limit.sh [-u/--user|-p/--password|-s/--secret_file|-w/--warning|-c/--critical|-d/--debug|-h/--help]
options:

parameters that use arguements:
    -u/--username                           specify user for authorized Docker Hub usage 
                                            if not specified this script uses the anonymous token given from docker hub.
    -p/--password                           specify password for user
    -s/--secret_file                        alternatively you can specify the location of a secret on the filesystem 
                                            (secret should be base64 encoded)
    -w/--warning                            specifiy warning threshold; default 80%
    -c/--critical                           specifiy critical threshold; default 90%
    -d/--debug                              activate debug mode ***warning secrets shall printed to the screen.
    -h/--help                               displays this message

Example usage:
    ./check_docker_rate_limit.sh
    ./check_docker_rate_limit.sh -u <user> -p <password>
    ./check_docker_rate_limit.sh --user <user> --password <password>
    ./check_docker_rate_limit.sh -s <file_location>
    ./check_docker_rate_limit.sh --secret_file <file_location>
    ./check_docker_rate_limit.sh -w 60 -c 70
    ./check_docker_rate_limit.sh --warning 60 --critical 70
    ./check_docker_rate_limit.sh --debug
    ./check_docker_rate_limit.sh --help"
}

# check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed - please install missing dependency jq. 
This could vary depending on which Linux distribution you are using.
On Debian-like systems you would install jq with the following command: 
'apt install jq'"
    exit 99
fi

##################################
# ARGS
##################################
while test $# -gt 0; do
    case "$1" in
        -h|--help)
            help
            exit 0
            ;;
        -d|--debug)
            shift
            SCRIPT_DEBUG="1"
            shift
            ;;
        -u|--username)
            shift
            DOCKER_HUB_USER=$1
            shift
            ;;
        -p|--password)
            shift
            DOCKER_HUB_PASSWORD=$1
            shift
            ;;
        -s|--secret_file)
            shift
            DOCKER_HUB_SECRET_FILE=$1
            shift
            ;;
        -c|--critical)
            shift
            CRIT=$1
            shift
            ;;
        -w|--warning)
            shift
            WARN=$1
            shift
            ;;
        *)   
            help
            break
            ;;
    esac
done

##################################
# VARIABLES
##################################
if [ -z "$DOCKER_HUB_USER" ] && [ -z "$DOCKER_HUB_SECRET_FILE" ]; then
    ANONYMOUS_CHECK_DOCKER_HUB=1

    DOCKER_RATE_LIMIT_TOKEN=$(
        curl \
        "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" \
        2>/dev/null | \
        jq -r .token
        )
else
    if ! [[ -z $DOCKER_HUB_USER ]] ; then
        ANONYMOUS_CHECK_DOCKER_HUB=0

        if [ -z $DOCKER_HUB_PASSWORD ]; then
            echo "Declared --username but no --password. Exiting."
            exit 1
        fi
        DOCKER_HUB_SECRET=$(echo "$DOCKER_HUB_USER:$DOCKER_HUB_PASSWORD")

    elif ! [[ -z $DOCKER_HUB_SECRET_FILE ]]; then
        ANONYMOUS_CHECK_DOCKER_HUB=0

        DOCKER_HUB_SECRET=$(echo $DOCKER_HUB_SECRET_FILE | base64 -d)
    fi

    DOCKER_RATE_LIMIT_TOKEN=$(
        curl --user "$DOCKER_HUB_SECRET" \
        "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" \
        2>/dev/null | \
        jq -r .token
    )
fi

if [ -z $WARN ]; then
    WARN=80
fi

if [ -z $CRIT ]; then
    CRIT=90
fi

QUERY=$(
    curl -q -s --head -H "Authorization: Bearer $DOCKER_RATE_LIMIT_TOKEN " \
    https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest \
    2>/dev/null
    )

DOCKER_RATELIMIT_SOURCE=$(
    echo "$QUERY" | \
    grep "docker-ratelimit-source" | \
    awk 'BEGIN {FS=": "};{printf $2}'
    )

DOCKER_RATELIMIT_LIMIT=$(
    echo "$QUERY" | \
    grep "ratelimit-limit" | \
    awk 'BEGIN {FS=": "};{printf $2}' | \
    awk 'BEGIN {FS=";"};{printf $1}'
    )

DOCKER_RATELIMIT_REMAINING=$(
    echo "$QUERY" | \
    grep "ratelimit-remaining" | \
    awk 'BEGIN {FS=": "};{printf $2}' | \
    awk 'BEGIN {FS=";"};{printf $1}'
    )

DOCKER_RATELIMIT_CAPACITY=$(
    echo $(( (($DOCKER_RATELIMIT_LIMIT-$DOCKER_RATELIMIT_REMAINING)*100 / ($DOCKER_RATELIMIT_LIMIT)) ))
    )

##################################
# FUNCTIONS
##################################

###########################
# DECLARE rate_limit_output
###########################
function rate_limit_output () {
    if [[ $DOCKER_RATELIMIT_REMAINING -eq 0 ]]; then
        SCRIPT_STATUS_OUTPUT=$(echo "Docker Hub pull rate limit reached for $DOCKER_RATELIMIT_SOURCE
    Get more information from:
    https://docs.docker.com/docker-hub/download-rate-limit/")

    elif [[ $DOCKER_RATELIMIT_REMAINING -eq 1 ]]; then
        SCRIPT_STATUS_OUTPUT=$(
            echo "$DOCKER_RATELIMIT_REMAINING image pull available out of $DOCKER_RATELIMIT_LIMIT for $DOCKER_RATELIMIT_SOURCE"
            )
    else
        SCRIPT_STATUS_OUTPUT=$(
            echo "$DOCKER_RATELIMIT_REMAINING image pulls available out of $DOCKER_RATELIMIT_LIMIT for $DOCKER_RATELIMIT_SOURCE"
            )
    fi

    if [[ $ANONYMOUS_CHECK_DOCKER_HUB -eq 0 ]]; then
        AUTHENTICATION_STATUS="AUTHENTICATED"
    else
        AUTHENTICATION_STATUS="ANONYMOUS"
    fi
    echo "$SCRIPT_STATUS_OUTPUT

DOCKER_RATELIMIT_CAPACITY: $DOCKER_RATELIMIT_CAPACITY%
DOCKER_RATELIMIT_REMAINING: $DOCKER_RATELIMIT_REMAINING
DOCKER_RATELIMIT_LIMIT: $DOCKER_RATELIMIT_LIMIT
AUTHENTICATION_TYPE: $AUTHENTICATION_STATUS
SRC_IP: $DOCKER_RATELIMIT_SOURCE"
}

#######################
# DECLARE check
#######################
function check () {
    if [ $DOCKER_RATELIMIT_CAPACITY -ge "$CRIT" ]; then
        echo "(CRITICAL): $(rate_limit_output)"
        exit 2
    elif [ $DOCKER_RATELIMIT_CAPACITY -ge "$WARN" ]; then
        echo "(WARNING): $(rate_limit_output)"
        exit 1
    elif [ $DOCKER_RATELIMIT_CAPACITY -lt "$WARN" ]; then
        echo "(OK): $(rate_limit_output)"
        exit 0
    else
        echo "(UNKOWN): Something went wrong. Please run command with --debug arg to maybe find out what went wrong."
        exit 3
    fi
}

##################################
# DEBUG SCRIPT
##################################
if [[ $SCRIPT_DEBUG -eq 1 ]]; then
    echo "===DEBUG START===
SECRETS used in this script have the following values:
  DOCKER_HUB_SECRET is $DOCKER_HUB_SECRET
Variables used in this script have the following values:
  warning threshold is $WARN% 
  critical threshold is $CRIT%.
  Docker rate limit capacity is $DOCKER_RATELIMIT_CAPACITY%.
Response from https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest looks like:
$QUERY===DEBUG END===
"
fi

##################################
# EXECUTE
##################################
check
