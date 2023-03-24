#!/bin/bash
set -eo pipefail
echo 'lint.sh - Lint BASH'

function ee {
    echo "$ $*"
    "$@"
}

### install dependencies ###
echo 'Installing dependencies.'
# install bashate
if bashate -h &> /dev/null; then
    echo 'Found bashate.'
else
    if pip3 --version &> /dev/null; then
        echo 'Found pip3.'
    else
        echo 'Installing pip3.'
        ee apt-get update
        ee apt-get install -y python3-pip
        echo 'Installed pip3.'
    fi
    ee pip3 --version
    echo 'Installing bashate.'
    ee pip3 install bashate
    echo 'Installed bashate.'
fi
# install jq
if jq --version &> /dev/null; then
    echo 'Found jq.'
else
    echo 'Installing jq.'
    ee apt-get update
    ee apt-get install -y jq
    echo 'Installed jq.'
fi
ee jq --version
# install shellcheck
if shellcheck --version &> /dev/null; then
    echo 'Found shellcheck.'
else
    echo 'Installing shellcheck.'
    ee apt-get update
    ee apt-get install -y shellcheck
    echo 'Installed shellcheck.'
fi
ee shellcheck --version
echo 'Done installing dependencies.'

### get shell scripts from action input or find them in directory tree ###
SANITIZED_INPUT_FILES="$(echo "$INPUT_FILES" | tr -d '[:space:]')"
if [[ -z "$INPUT_FILES" || "$SANITIZED_INPUT_FILES" == '[]' || "$SANITIZED_INPUT_FILES" == 'null' || "$SANITIZED_INPUT_FILES" == 'undefined' ]]; then
    echo "Finding shell scripts in \"$(pwd)\"."
    FILES="$(find . -type f -name '*.sh' -o -name '*.bash' -not -path '.git' | sort | jq -R -s -c 'split("\n")[:-1]')"
    echo "Found $(echo "$FILES" | jq 'length') shell scripts in \"$(pwd)\"."
else
    echo 'Linting shell scripts given in action input.'
    FILES="$(echo "$INPUT_FILES" | jq -c 'map(select(length > 0 and (. != null)))')"
    echo "Found $(echo "$FILES" | jq 'length') shell scripts from action input."
fi

### lint BASH ###
set +e
# lint with bashate
ee bashate -i E006
BASHATE_EXIT_STATUS="$?"

# lint with shellcheck
ee shellcheck -x -f gcc
SHELLCHECK_EXIT_STATUS="$?"
set -e

### report results ###
if [[ "$BASHATE_EXIT_STATUS" != '0' && "$SHELLCHECK_EXIT_STATUS" != '0' ]]; then
    echo 'ERROR: Both bashate and shellcheck found problems!'
    exit 1
elif [[ "$BASHATE_EXIT_STATUS" != '0' ]]; then
    echo 'ERROR: bashate found problems!'
    exit "$BASHATE_EXIT_STATUS"
elif [[ "$SHELLCHECK_EXIT_STATUS" != '0' ]]; then
    echo 'ERROR: ShellCheck found problems!'
    exit "$SHELLCHECK_EXIT_STATUS"
else
    echo 'Congratulations, your BASH looks great!'
fi

echo 'Done - lint.sh - Lint BASH'
