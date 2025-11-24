#!/bin/bash

[[ $- != *i* ]] && return

### Features
#
# Compatible with both Linux and MacOS
#
# Prompt:
# Multiline prompt that expands to width of terminal
# green :) when command exits successfully, red :( when error
# Displays current username and directory. Shortens home directory to "~"
# Changes parens surrounding directory to red when in a directory the user does not have write permissions
# When in a git repo, display the current branch
# - Yellow if clean, red if dirty
#
# Bash Completion:
# cdgit <tab> to complete with git directories.
# * runs nvm to switch to .nvmrc defined node version
# yarn <tab> : completes programs in node_modules/.bin
# yarn run <tab> : completes scripts defined in package.json
#
# Runs tmux automatically
# Runs lsd or exa instead of ls, if available. Defines sane color defaults
# Maps Ctrl+R to hstr (replaces default history search)
# * Removes per session history for terminals
# Colorize man pages
# Set default editor to emacs (no window), if it is installed
# alias top command to htop
# Installs direnv hooks

# Work around for NVM bug with tmux
# https://github.com/creationix/nvm/issues/1652
if [[ "$OSTYPE" == "darwin"* ]]; then
  PATH="/usr/local/bin:$(getconf PATH)"
fi

###############################################################################
# Variables

if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -f /etc/bashrc ]; then
	source /etc/bashrc
fi

splash_files=("$HOME"/.splashes/*)

export LOCALBIN="$HOME/bin"
export GITHOME="$HOME/Documents/GIT"
export SPLASH_SCREEN="${splash_files[RANDOM % ${#splash_files[@]}]}"
export GOPATH="${HOME}/.go"
export GOROOT="$(brew --prefix golang)/libexec"
export SNAPBIN="/snap/bin"
export EXA_COLORS="ex=0;0;31:di=0;0;34:da=0;0;37:*.pdf=0;0;33:*.doc=0;0;33:*.docx=0;0;33:*.xls=0;0;33:*.xlsx=0;0;33:*.ppt=0;0;33:*.pptx=0;0;33:*.dot=0;0;33:*.wpd=0;0;33:*.wps=0;0;33:*.sdw=0;0;33:*.odt=0;0;33:*.ods=0;0;33:*.odg=0;0;33:*.odp=0;0;33:*.odf=0;0;33:*.odb=0;0;33:*.oxt=0;0;33:*.eml=0;0;37:*.zip=38;5;205:*.gz=38;5;205:*.tar=38;5;205:*.dmg=38;5;205:*.rar=38;5;205:*.tgz=38;5;205:.java=38;5;45:*.kt;0;0;37:*.c=38;5;45:*.cpp=38;5;45:*.h=38;5;45:*.js=38;5;45:*.jsx=38;5;45:*.ts=38;5;45:*.tsx=38;5;45:*.rb=38;5;45:*.pl=38;5;45:*.py=38;5;45:*.go=38;5;45:*.php=38;5;45:*.sh=38;5;45:*.bat=38;5;45:*.lua=38;5;45:*.swift=38;5;45:*.xsl=38;5;45:*.d=38;5;45:*.tcl=38;5;45:*.pas=38;5;45:*.vbs=38;5;45:*.groovy=38;5;45:*.lsp=38;5;45:*.ps1=38;5;45:*.bcc=38;5;45:*.rs=38;5;45:*.html=38;5;121:*.css=38;5;121:*.less=38;5;121:*.sass=38;5;121:*.xhtml=38;5;43:*.htm=38;5;121:*.mustache=38;5;121:*.json=38;5;85:*.sql=38;5;85:*.eml=38;5;85:*.csv=38;5;85:*.xml=38;5;85:*.yml=38;5;85:*.yaml=38;5;85"
export LS_COLORS="ex=0;0;31:di=0;0;34:da=0;0;37:*.pdf=0;0;33:*.doc=0;0;33:*.docx=0;0;33:*.xls=0;0;33:*.xlsx=0;0;33:*.ppt=0;0;33:*.pptx=0;0;33:*.dot=0;0;33:*.wpd=0;0;33:*.wps=0;0;33:*.sdw=0;0;33:*.odt=0;0;33:*.ods=0;0;33:*.odg=0;0;33:*.odp=0;0;33:*.odf=0;0;33:*.odb=0;0;33:*.oxt=0;0;33:*.eml=0;0;37:*.zip=38;5;205:*.gz=38;5;205:*.tar=38;5;205:*.dmg=38;5;205:*.rar=38;5;205:*.tgz=38;5;205:.java=38;5;45:*.kt;0;0;37:*.c=38;5;45:*.cpp=38;5;45:*.h=38;5;45:*.js=38;5;45:*.jsx=38;5;45:*.ts=38;5;45:*.tsx=38;5;45:*.rb=38;5;45:*.pl=38;5;45:*.py=38;5;45:*.go=38;5;45:*.php=38;5;45:*.sh=38;5;45:*.bat=38;5;45:*.lua=38;5;45:*.swift=38;5;45:*.xsl=38;5;45:*.d=38;5;45:*.tcl=38;5;45:*.pas=38;5;45:*.vbs=38;5;45:*.groovy=38;5;45:*.lsp=38;5;45:*.ps1=38;5;45:*.bcc=38;5;45:*.rs=38;5;45:*.html=38;5;121:*.css=38;5;121:*.less=38;5;121:*.sass=38;5;121:*.xhtml=38;5;43:*.htm=38;5;121:*.mustache=38;5;121:*.json=38;5;85:*.sql=38;5;85:*.eml=38;5;85:*.csv=38;5;85:*.xml=38;5;85:*.yml=38;5;85:*.yaml=38;5;85"

# Source git-related functions
if [ -f "$HOME/.config/bashrc/git.sh" ]; then
  source "$HOME/.config/bashrc/git.sh"
fi

# Source znt (Zellij new tab function)
if [ -f "$HOME/.config/bashrc/znt.sh" ]; then
  source "$HOME/.config/bashrc/znt.sh"
fi

# Setup Path

mkdir -p "${HOME}/.local/bin"
PATH="$HOME/.local/bin:$LOCALBIN:/usr/local/bin:/usr/bin:/bin:$PATH"

if [[ -d "$SNAPBIN" ]]; then
  PATH="$PATH:$SNAPBIN"
fi

if [[ -d "$HOME/.cargo/bin" ]]; then
  PATH="$PATH:$HOME/.cargo/bin"
fi

if [[ -d "$GOPATH/bin" ]]; then
  PATH="$PATH:${GOPATH}/bin"
fi

if [[ -d "$GOROOT/bin" ]]; then
  PATH="$PATH:${GOROOT}/bin"
fi

if [[ -d "$LOCALBIN/flutter/bin" ]]; then
  PATH="$PATH:$LOCALBIN/flutter/bin"
fi

export PATH

# Setup Visual Studio Code executable
code_symlink="${HOME}/.local/bin/code"
if [[ -e /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code && ! -e ${code_symlink} ]]; then
  ln -s /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code "${code_symlink}"
fi

# command history

export SHELL_SESSION_HISTORY=0
export HH_CONFIG=hicolor         # get more colors
shopt -s histappend              # append new history items to .bash_history
export HISTCONTROL=ignorespace   # leading space hides commands from history
export HISTFILESIZE=10000        # increase history file size (default is 500)
export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)

# Set emacs as default system editor
if [ -x "$(command -v emacs)" ]; then
    export EDITOR="emacs -nw"
    alias xemacs="emacs"
fi

if [ -x "$(command -v difft)" ]; then
  export GIT_EXTERNAL_DIFF=difft
fi

###############################################################################
# Aliases

# Silver Searcher searches hidden files
alias ag='ag --hidden --ignore ".git"'
alias curltime='curl -w "@$HOME/.curl-time" -s '

case $OSTYPE in
  linux*)
    alias ls='ls --color'
    alias df="df -x squashfs"

    # Reset HiDPI settings
    alias resetScreen='xrandr -s 0 --dpi 192XSX'

    # use htop instead of top
    if [[ -x $(command -v htop) ]]; then
      alias top='htop'
    fi

    # Load tmux with linux config
    alias tmux="tmux -f ~/.tmux/configs/tmux.linux.conf"

    # Alias to run GUI apps with `sudo` in Wayload
    alias allowGuiAsRoot="xhost +si:localuser:root > /dev/null"
    ;;
  darwin*)
    alias ls='ls -G'

    # Flush the DNS cache / reload /etc/hosts
    alias flushDNS='dscacheutil -flushcache'

    # Remove cache files to speed up terminal
    alias cleanup='sudo rm -f /private/var/log/asl/*.asl'

    # Filemerge tool
    alias filemerge="open /Applications/Xcode.app/Contents/Applications/FileMerge.app/"

    # Load tmux with Mac config
    alias tmux="tmux -f ~/.tmux/configs/tmux.macos.conf"
    ;;
  *) ;;
esac

# If `lsd` or `exa` is installed, use it instead of ls
if [ -x "$(command -v lsd)" ]; then
  alias ls="lsd"
elif [ -x "$(command -v exa)" ]; then
  alias ls="exa"
else
  alias ls="ls --color"
fi

# If `duf` is installed, use it instead of df
if [ -x "$(command -v duf)" ]; then
  alias df='duf --output mountpoint,used,size,avail,usage,type --sort used  --hide-fs nullfs --hide special --width $((COLUMNS+20))'
  alias duf='duf --output mountpoint,used,size,avail,usage,type --sort used  --hide-fs nullfs --hide special --width $((COLUMNS+20))'
fi

if [ -x "$(command -v dust)" ]; then
  alias du='dust -n 100'
fi

alias claude-monitor='docker run --rm -it -v $HOME/.claude:/root/.claude walkerlee/claude-monitor'

function udm() {
  if [ -f "yarn.lock" ]; then
    yarn "$@"
  else
    npm "$@"
  fi
}

# make man pages colorful
function _colorman() {
  env \
    LESS_TERMCAP_mb="$(printf '\e[1;35m')" \
    LESS_TERMCAP_md="$(printf '\e[1;34m')" \
    LESS_TERMCAP_me="$(printf '\e[0m')" \
    LESS_TERMCAP_se="$(printf '\e[0m')" \
    LESS_TERMCAP_so="$(printf '\e[7;40m')" \
    LESS_TERMCAP_ue="$(printf '\e[0m')" \
    LESS_TERMCAP_us="$(printf '\e[1;33m')" \
    GROFF_NO_SGR=1 \
      "$@"
}
function man() { _colorman man "$@"; }

# emacs
if [ -f /Applications/Emacs.app/Contents/MacOS/Emacs ]
then
    alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs --no-splash"
elif [ -f /usr/local/bin/emacs ]
then
    alias emacs="/usr/local/bin/emacs --no-splash -nw"
else
    alias emacs="emacs --no-splash -nw"
fi

function trim_newline_from_eof {
  if [[ -z $1 ]]; then
    echo "No filename provided"
    return 1
  fi
  if [[ ! -f $1 ]]; then
    echo "Filename is not a file"
    return 1
  fi
  perl -pi -e 'chomp if eof' "$1"
}

###############################################################################
# Splash Screen

if [[ "$TERM_PROGRAM" != "WarpTerminal" ]]; then
    cat "$SPLASH_SCREEN"
fi

###############################################################################
# Setup cat

function _cat() {
  FILE=${@: -1}
  if [[ -x "$(command -v mdcat)" && ( "${FILE##*.}" = "md" || "${FILE##*.}" = "markdown" ) ]]
  then
    mdcat "$@"
  else
    cat "$@"
  fi
}
alias cat="_cat"

###############################################################################
# Prompt


  LIGHT_BLUE="\\[\\033[0;34m\\]"
  CYAN_BOLD="\\[\\033[1;36m\\]"
  NO_COLOUR="\\[\\033[0m\\]"
  GREEN="\\[\\033[1;32m\\]"
  CYAN="\\[\\033[0;36m\\]"
  RED="\\[\\033[1;31m\\]"
  YELLOW="\\[\\033[1;33m\\]"

  EXIT_SMILEY=":-/"

  GITCOLOR=$YELLOW

  function prompt {
    EXIT_STATUS=$?

    # for `hstr`
    history -a # Append history lines from the current session to the history file
    history -n # Read the history file into memory

    TERMWIDTH=${COLUMNS}

    usernam=$(whoami)

    newPWD="${PWD}"
    newPWD="$(echo -n "${PWD}" | sed -e "s|$HOME|\\~|")"

    pwdSurroundColor=$LIGHT_BLUE
    if [[ ! -w ${PWD} ]]; then
      pwdSurroundColor=$RED
    fi

    gitBranch=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
    if [[ -z $gitBranch ]]; then
      gitBranch=$(date +%H:%M);
      GITCOLOR=$CYAN;
    else
      GITCOLOR=$YELLOW;
    fi

    gitDirty=$(git status --porcelain 2> /dev/null)
    if [[ -n $gitDirty ]]; then
      GITCOLOR=$RED;
    fi

    (( promptsize=$(echo -n "--(${usernam}@${newPWD})---(${gitBranch})--" | wc -c | tr -d " ") ))
    (( fillsize=TERMWIDTH-promptsize ))

    fill=""
    while [[ $fillsize -gt 0 ]]; do
      fill="${fill}-===--===-"
      (( fillsize=fillsize-10 ))
    done

    if [[ $fillsize -lt 0 ]]; then
      (( cut=0-fillsize ))
      fill="$(echo -n $fill | sed -e "s/\\(^.\\{$cut\\}\\)\\(.*\\)/\\2/")"
    fi

    if [[ $EXIT_STATUS -ne 0 ]]; then
      EXIT_SMILEY="$RED:("
    else
      EXIT_SMILEY="$GREEN:)"
    fi

    PS1="$CYAN_BOLD-$pwdSurroundColor-($CYAN\${usernam}$LIGHT_BLUE@$CYAN\${newPWD}${pwdSurroundColor})-${CYAN_BOLD}-\${fill}${LIGHT_BLUE}-($GITCOLOR\${gitBranch}$LIGHT_BLUE)-$CYAN_BOLD-\\n$CYAN_BOLD-$LIGHT_BLUE-($CYAN$EXIT_SMILEY$LIGHT_BLUE)-$CYAN_BOLD-:$NO_COLOUR "
}

if [[ "$TERM_PROGRAM" != "WarpTerminal" ]]; then
  PROMPT_COMMAND=prompt
fi

# Setup hstr
# Bind `hstr` to Ctrl+r, if this is interactive shell,
if [[ $- =~ .*i.* ]]; then bind '"\C-r": "\C-a hh -- \C-j"'; fi

###############################################################################
# Auto completion functions

# for hostnames with SSH, based on known_hosts file
# function _autoComplete_Hostname() {
# 	local hosts;
# 	local cur;
# 	hosts=($(awk '{print $1}' ~/.ssh/known_hosts | cut -d, -f1));
# 	cur=${COMP_WORDS[COMP_CWORD]};
# 	COMPREPLY=($(compgen -W '${hosts[@]}' -- $cur ))
# }
# complete -F _autoComplete_Hostname ssh

# flutter bash completion
if [ -x "$(command -v flutter)" ]; then
  eval "$(flutter bash-completion)"
fi

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

# Adds in a ton of autocompletes for bash
if [[ -f $LOCALBIN/bash_completion ]]; then
  # shellcheck source=/dev/null
  source "$LOCALBIN/bash_completion"
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# shellcheck source=/dev/null
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
if [[ -f .nvmrc && -z "$NVM_USED" ]]; then
  # If .nvmrc exists in the directory where the shell opens
  nvm use
fi

if [ -f "$HOME/.local_profile" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.local_profile"
fi

# if ! [[ "$TERM" = "screen-256color" ]] && ! [[ -n "$TMUX" ]] || [[ "$TERM_PROGRAM" = "vscode" ]]; then
#  tmux
# fi

if [[ -z "$ZELLIJ" ]] && ! [[ "$TERM_PROGRAM" = "vscode" ]] && ! [[ "$TERM_PROGRAM" = "WarpTerminal" ]]; then
  if [[ "$ZELLIJ_AUTO_ATTACH" == "true" ]]; then
    zellij attach -c
  else
    zellij
  fi

  if [[ "$ZELLIJ_AUTO_EXIT" == "true" ]]; then
    exit
  fi
fi

if [[ -x $(command -v direnv) ]]; then
  eval "$(direnv hook bash)"
fi

# bash completion for python invoke
_complete_invoke() {
    local candidates
    candidates=$(invoke --complete -- "${COMP_WORDS[*]}")
    COMPREPLY=( $(compgen -W "${candidates}" -- "$2") )
}
complete -F _complete_invoke -o default invoke inv

if [ -d "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  #THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

if [[ -x $(command -v just) ]]; then
  eval "$(just --completions bash)"
fi
