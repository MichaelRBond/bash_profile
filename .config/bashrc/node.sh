#!/bin/bash
# Node.js package manager functions and completions
#
# Features:
# - udm: Universal dependency manager (auto-detects yarn vs npm)
# - yarn/npm/pnpm <tab>: Completes node_modules/.bin binaries
# - yarn/npm/pnpm run <tab>: Completes scripts from package.json
# - yarn/npm/pnpm add|remove <tab>: Completes installed packages
# - yarn why <tab>: Completes installed modules
# - NVM initialization with auto .nvmrc detection

# Universal dependency manager - automatically uses yarn or npm
function udm() {
  if [ -f "yarn.lock" ]; then
    yarn "$@"
  else
    npm "$@"
  fi
}

# yarn <tab> : Lists commands from `node_modules/.bin`
# yarn run <tab> : Scripts from package.json (correctly handles `:` in script names)
# yarn why <tab> : installed modules
# yarn add | remove <tab> : dependencies and devDependencies from package.json
function _autoComplete_yarn_run() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"

  local yarn_cmd
  yarn_cmd="${COMP_WORDS[1]}"

  local dir
  dir=$(pwd)
  if [ "${yarn_cmd}" == "run" ]; then
    if [ ! -f "${dir}/package.json" ]; then
      return
    fi
    local scripts
    scripts=$(jq -r '.scripts | keys[]' "${dir}/package.json")
    _get_comp_words_by_ref -n : -c cur
    COMPREPLY=( $(compgen -W "${scripts}" "${cur}") )
    __ltrim_colon_completions "$cur"
    return
  elif [ "${yarn_cmd}" == "remove" ] || [ "${yarn_cmd}" == "add" ]; then
    if [ ! -f "${dir}/package.json" ]; then
      return
    fi
    local packages
    packages=$(jq -r '.dependencies * .devDependencies | keys[]' "${dir}/package.json")
    _get_comp_words_by_ref -n : -c cur
    COMPREPLY=( $(compgen -W "${packages}" "${cur}") )
    __ltrim_colon_completions "$cur"
    return
  elif [ "${yarn_cmd}" == "why" ]; then
    local modules
    modules=$(yarn list --depth 0 | sed -n 's/.* \([a-zA-Z0-9@].*\)@.*/\1/p') || return 1
    COMPREPLY=( $(compgen -W "${modules}" -- "$cur") )
    return
  elif [ -z "${yarn_cmd}" ]; then
    if [ ! -d "${dir}/node_modules/.bin" ]; then
      return
    fi
    node_modules_cmds=$(ls "$dir/node_modules/.bin/")
    COMPREPLY=( $(compgen -W "${node_modules_cmds}" -- "$cur") )
    return
  else
    # fall back to directory completion. Useful for commands that take a path
    _filedir
  fi
}

complete -F _autoComplete_yarn_run yarn
complete -F _autoComplete_yarn_run npm
complete -F _autoComplete_yarn_run pnpm

# NVM initialization
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# shellcheck source=/dev/null
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
if [[ -f .nvmrc && -z "$NVM_USED" ]]; then
  # If .nvmrc exists in the directory where the shell opens
  nvm use
fi
