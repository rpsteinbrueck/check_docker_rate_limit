# check_docker_rate_limit

check_docker_rate_limit.sh is a shell script which was written to monitor the Docker Hub rate limit status.
Docker Hub throttles container Image pulling and data storage uploading for fair use of their service.

This check was built on the commands which Docker Hub describe in their own documentation found under:
https://docs.docker.com/docker-hub/download-rate-limit/#how-can-i-check-my-current-rate

## Output (No authentication)

```shell
$ ./check_docker_rate_limit.sh
(OK): 100 image pulls available out of 100 for x.x.x.x

DOCKER_RATELIMIT_CAPACITY: 0%
DOCKER_RATELIMIT_REMAINING: 100
DOCKER_RATELIMIT_LIMIT: 100
AUTHENTICATION_TYPE: ANONYMOUS
SRC_IP: x.x.x.x

```

## Dependencies

-   jq

On Debian-like distributions you can achieve jq installation with the following command:

```shell
$ apt install jq
```

## Help:

```shell
$ ./check_docker_rate_limit.sh --help
check_docker_rate_limit.sh 0.0.1
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
    ./check_docker_rate_limit.sh --help
```

## Licensing

check_docker_rate_limit is licensed under MIT license.
See [LICENSE](LICENSE) for the full license text.
