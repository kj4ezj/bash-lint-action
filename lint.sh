#!/bin/bash
set -eo pipefail
echo "Begin - ${0##*/}"

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
SANITIZED_INPUT="$(echo "$INPUT_FILES" | tr -d '[:space:]')"
if [[ -z "$SANITIZED_INPUT" || "$SANITIZED_INPUT" == '[]' || "$SANITIZED_INPUT" == 'null' || "$SANITIZED_INPUT" == 'undefined' ]]; then
    echo 'Action input is undefined, null, or empty.'
    echo "Finding shell scripts in \"$(pwd)\"."
    FILES="$(find . -type f -name '*.sh' -o -name '*.bash' -not -path '.git' | sort | jq -R -s -c 'split("\n")[:-1]')"
    echo "Found $(echo "$FILES" | jq 'length') shell scripts in \"$(pwd)\"."
else
    echo 'Linting shell scripts given in action input.'
    FILES="$(echo "$INPUT_FILES" | jq -c 'map(select(length > 0 and (. != null)))')"
    echo "Found $(echo "$FILES" | jq 'length') shell scripts from action input."
fi

### lint BASH ###
EXIT_STATUS='0'
for SCRIPT in $(echo "$FILES" | jq -r '.[] | @base64'); do
    SCRIPT="$(echo "$SCRIPT" | base64 --decode)"
    echo "Linting \"$SCRIPT\"."
    ee bashate -i E006 "$SCRIPT" || EXIT_STATUS="$?"
    ee shellcheck -x -f gcc "$SCRIPT" || EXIT_STATUS="$?"
done

### report results ###
if [[ "$EXIT_STATUS" == '0' ]]; then
    printf '\033[1;32mSUCCESS - Linting passed! :D\n\033[0m'
else
    printf '\033[1;31mFAILURE - Linting failed. :/\n\033[0m'
fi

echo "Done. - ${0##*/}"
exit "$EXIT_STATUS"
