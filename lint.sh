#!/bin/bash
set -eo pipefail
echo "Begin - ${0##*/}"

function ee {
    echo "$ $*"
    "$@"
}

ee jq --version
ee shellcheck --version

### get shell scripts from action input or find them in directory tree ###
echo '::group::🔍 Find Shell Scripts 🔍::collapsed=true'
SANITIZED_INPUT="$(echo "$INPUT_FILES" | tr -d '[:space:]')"
if [[ -z "$SANITIZED_INPUT" || "$SANITIZED_INPUT" == '[]' || "$SANITIZED_INPUT" == 'null' || "$SANITIZED_INPUT" == 'undefined' ]]; then
    echo 'Action input is undefined, null, or empty.'
    echo "Finding shell scripts in \"$(pwd)\"."
    FILES="$(find . -type f -name '*.sh' -o -name '*.bash' -not -path '.git' | sort | jq -R -s -c 'split("\n")[:-1]')"
    echo "Found $(echo "$FILES" | jq 'length') shell script(s) in \"$(pwd)\"."
else
    echo 'Linting shell scripts given in action input.'
    if [[ "$(echo "$INPUT_FILES" | jq -r 'type')" != 'array' ]]; then
        printf '\033[1;31mERROR: Action input is not an array!\n\033[0m'
        echo "Found $(echo "$INPUT_FILES" | jq 'type') type."
        exit 1
    fi
    FILES="$(echo "$INPUT_FILES" | jq -c 'map(select(length > 0 and (. != null)))')"
    echo "Found $(echo "$FILES" | jq 'length') shell script(s) from action input."
fi
echo '::endgroup::'

### lint BASH ###
echo '::group::🧹 Lint BASH 🧹::collapsed=false'
EXIT_STATUS='0'
for SCRIPT in $(echo "$FILES" | jq -r '.[] | @base64'); do
    SCRIPT="$(echo "$SCRIPT" | base64 --decode)"
    echo "Linting \"$SCRIPT\"."
    ee bashate -i E006 "$SCRIPT" || EXIT_STATUS="$?"
    ee shellcheck -x -f gcc "$SCRIPT" || EXIT_STATUS="$?"
done
echo 'Done linting.'
echo '::endgroup::'

### report results ###
if [[ "$EXIT_STATUS" == '0' ]]; then
    printf '\033[1;32mSUCCESS - Linting passed! :D\n\033[0m'
else
    printf '\033[1;31mFAILURE - Linting failed. :/\n\033[0m'
    echo '::error::BASH Linting Failed. :/'
fi

echo "Done. - ${0##*/}"
exit "$EXIT_STATUS"
