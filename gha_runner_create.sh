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

    # Determine runner version
    GH_RUNNER_VERSION="${GH_RUNNER_VERSION:-}"
    if [[ -z "$GH_RUNNER_VERSION" ]]; then
        echo "Fetching latest runner version from GitHub..."
        GH_RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/v//')
        if [[ -z "$GH_RUNNER_VERSION" ]]; then
            echo "Failed to fetch latest runner version. Aborting." >&2
            exit 1
        fi
    fi
    echo "Using runner version: $GH_RUNNER_VERSION"

    # Update runner in persistent volume
    docker run --rm \
        -v "$(pwd)/actions-runner:/actions-runner" \
        --entrypoint /bin/bash rodnymolina588/gha-sysbox-runner:latest -c "cd /actions-runner && \
            curl -L -o actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz && \
            tar xzf actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz && \
            rm actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz && \
            ./bin/installdependencies.sh"

    # Parse env_vars argument (key=value pairs separated by spaces)
    env_args=""
    if [[ -n "$env_vars" ]]; then
        for pair in $env_vars; do
            env_args+=" -e $pair"
        done
    fi

    echo "Starting runner container..."
    docker run -d --restart=always \
        --runtime=sysbox-runc \
        --cap-add=SYS_RESOURCE \
        --ulimit nofile=1048576 \
        -v "$(pwd)/actions-runner:/actions-runner" \
        -e REPO_URL="https://github.com/${org}/${repo}" \
        -e RUNNER_TOKEN="$token" \
        -e RUNNER_NAME="$name" \
        -e RUNNER_GROUP="" \
        -e LABELS="" \
        $env_args \
        --name "$name" rodnymolina588/gha-sysbox-runner:latest
}

function main() {
    if [[ $# -lt 4 ]]; then
        printf "\nerror: Unexpected number of arguments provided\n"
        printf "\nUsage: ./gha_runner_create.sh <runner-name> <org> <repo-name> <runner-token> [ENV_VAR1=val1 ENV_VAR2=val2 ...]\n\n"
        exit 2
    fi

    # Save first 4 args
    name="$1"
    org="$2"
    repo="$3"
    token="$4"

    # Collect env-vars (all args after the 4th)
    env_vars=""
    if [[ $# -gt 4 ]]; then
        shift 4
        env_vars="$@"
    fi

    create_sysbox_gha_runner "$name" "$org" "$repo" "$token" "$env_vars"
}

main "$@"
