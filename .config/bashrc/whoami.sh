#!/usr/bin/env bash

whoami() {
    echo "local: $(command whoami)"

    if ! command -v aws >/dev/null 2>&1; then
        return
    fi

    local arn
    arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null) || return

    local username="${arn##*/}"
    local account
    account=$(printf '%s\n' "$arn" | awk -F: '{print $5}')

    local env="unknown"
    local entry
    for entry in "${AWS_ACCOUNTS[@]}"; do
        if [[ "${entry%%:*}" == "$account" ]]; then
            env="${entry#*:}"
            break
        fi
    done

    echo "aws: ${username}@${env}"

    if ! command -v heroku >/dev/null 2>&1; then
        return
    fi

    local heroku_user
    heroku_user=$(heroku auth:whoami 2>/dev/null) || return
    echo "heroku: ${heroku_user}"
}
