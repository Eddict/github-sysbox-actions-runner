#!/bin/bash
#
# Simple bash wrapper to create sysbox-based github-actions runners. Script can be easily
# extended to accommodate the various config options offered by the GHA runner.
#

set -o errexit
set -o pipefail
set -o nounset

# Function creates a per-repo runner; it can be easily extended to support org-level
# runners by passing a PAT as ACCESS_TOKEN and set RUNNER_SCOPE="org".
function create_sysbox_gha_runner {
    name=$1
    org=$2
    repo=$3
    token=$4
    env_vars=$5

    docker rm -f "$name" >/dev/null 2>&1 || true

    # Parse env_vars argument (key=value pairs separated by spaces)
    env_args=""
    if [[ -n "$env_vars" ]]; then
        for pair in $env_vars; do
            env_args+=" -e $pair"
        done
    fi

    docker run -d --restart=always \
        --runtime=sysbox-runc \
        -e REPO_URL="https://github.com/${org}/${repo}" \
        -e RUNNER_TOKEN="$token" \
        -e RUNNER_NAME="$name" \
        -e RUNNER_GROUP="" \
        -e LABELS="" \
        $env_args \
        --name "$name" rodnymolina588/gha-sysbox-runner:latest

        # --cap-add=SYS_RESOURCE \
        # --ulimit nofile=1048576 \
}

function main() {
    if [[ $# -lt 4 ]]; then
        printf "\nerror: Unexpected number of arguments provided\n"
        printf "\nUsage: ./gha_runner_create.sh <runner-name> <org> <repo-name> <runner-token> [ENV_VAR1=val1 ENV_VAR2=val2 ...]\n\n"
        exit 2
    fi

    # Collect env-vars (all args after the 4th)
    env_vars=""
    if [[ $# -gt 4 ]]; then
        shift 4
        env_vars="$@"
        # Restore positional params for first 4 args
        set -- "$1" "$2" "$3" "$4"
    fi

    create_sysbox_gha_runner "$1" "$2" "$3" "$4" "$env_vars"
}

main "$@"
