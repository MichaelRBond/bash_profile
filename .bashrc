# Work around for NVM bug with tmux
# https://github.com/creationix/nvm/issues/1652
if [[ "$OSTYPE" == "darwin"* ]]; then
  PATH="/usr/local/bin:$(getconf PATH)"
fi

###############################################################################
# Variables

if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

files=($HOME/.splashes/*)

export LOCALBIN=$HOME/bin
export GITHOME=$HOME/Dropbox/GIT
export SPLASH_SCREEN="${files[RANDOM % ${#files[@]}]}"
export GOPATH=$GITHOME/go/
export PATH=$HOME/tmp:$LOCALBIN:/usr/local/bin:/usr/local/go/bin:$GOPATH/bin:$PATH
export EXA_COLORS="ex=0;0;31:di=0;0;34:da=0;0;37:*.pdf=0;0;33:*.doc=0;0;33:*.docx=0;0;33:*.xls=0;0;33:*.xlsx=0;0;33:*.ppt=0;0;33:*.pptx=0;0;33:*.dot=0;0;33:*.wpd=0;0;33:*.wps=0;0;33:*.sdw=0;0;33:*.odt=0;0;33:*.ods=0;0;33:*.odg=0;0;33:*.odp=0;0;33:*.odf=0;0;33:*.odb=0;0;33:*.oxt=0;0;33:*.eml=0;0;37:*.zip=38;5;205:*.gz=38;5;205:*.tar=38;5;205:*.dmg=38;5;205:*.rar=38;5;205:*.tgz=38;5;205:.java=38;5;45:*.kt;0;0;37:*.c=38;5;45:*.cpp=38;5;45:*.h=38;5;45:*.js=38;5;45:*.jsx=38;5;45:*.ts=38;5;45:*.tsx=38;5;45:*.rb=38;5;45:*.pl=38;5;45:*.py=38;5;45:*.go=38;5;45:*.php=38;5;45:*.sh=38;5;45:*.bat=38;5;45:*.lua=38;5;45:*.swift=38;5;45:*.xsl=38;5;45:*.d=38;5;45:*.tcl=38;5;45:*.pas=38;5;45:*.vbs=38;5;45:*.groovy=38;5;45:*.lsp=38;5;45:*.ps1=38;5;45:*.bcc=38;5;45:*.rs=38;5;45:*.html=38;5;121:*.css=38;5;121:*.less=38;5;121:*.sass=38;5;121:*.xhtml=38;5;43:*.htm=38;5;121:*.mustache=38;5;121:*.json=38;5;85:*.sql=38;5;85:*.eml=38;5;85:*.csv=38;5;85:*.xml=38;5;85:*.yml=38;5;85:*.yaml=38;5;85"

# command history

export SHELL_SESSION_HISTORY=0
export HH_CONFIG=hicolor         # get more colors
shopt -s histappend              # append new history items to .bash_history
export HISTCONTROL=ignorespace   # leading space hides commands from history
export HISTFILESIZE=10000        # increase history file size (default is 500)
export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)

# Set emacs as default system editor
export EDITOR=emacs

###############################################################################
# Aliases

# Silver Searcher searches hidden files
alias ag='ag --hidden'

case $OSTYPE in
  linux*)
    alias ls='ls --color'

    # Reset HiDPI settings
    alias resetScreen='xrandr -s 0 --dpi 192XSX'

    # use htop instead of top
    alias top='htop'

    # Load tmux with linux config
    alias tmux="tmux -f ~/.tmux/configs/tmux.linux.conf"
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

# If `exa` is installed, use it instead of ls
if [ -x "$(command -v exa)" ]; then
  alias ls="exa"
fi

# make man pages colorful
function _colorman() {
  env \
    LESS_TERMCAP_mb=$(printf "\e[1;35m") \
    LESS_TERMCAP_md=$(printf "\e[1;34m") \
    LESS_TERMCAP_me=$(printf "\e[0m") \
    LESS_TERMCAP_se=$(printf "\e[0m") \
    LESS_TERMCAP_so=$(printf "\e[7;40m") \
    LESS_TERMCAP_ue=$(printf "\e[0m") \
    LESS_TERMCAP_us=$(printf "\e[1;33m") \
      "$@"
}
function man() { _colorman man "$@"; }

# emacs
if [ -f /Applications/Emacs.app/Contents/MacOS/Emacs ]
then
    alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs --no-splash"
else
    alias emacs="emacs --no-splash -nw"
fi

#change into my base Git repo directory, or into a specific project directory
function cdgit {

    if [ ! -n "$1" ]
    then
	    cd $GITHOME
    else
    	cd $GITHOME/$1
    fi

    if [ -f ".nvmrc" ]
    then
	    nvm use
    fi
}
export -f cdgit

###############################################################################
# Splash Screen

cat $SPLASH_SCREEN

###############################################################################
# Prompt

LIGHT_BLUE="\[\033[0;34m\]"
CYAN_BOLD="\[\033[1;36m\]"
NO_COLOUR="\[\033[0m\]"
GREEN="\[\033[1;32m\]"
CYAN="\[\033[0;36m\]"
RED="\[\033[1;31m\]"
YELLOW="\[\033[1;33m\]"

EXIT_SMILEY=":-/"

GITCOLOR=$YELLOW

function prompt {

EXIT_STATUS=$?

TERMWIDTH=${COLUMNS}

usernam=$(whoami)
let usersize=$(echo -n $usernam | wc -c | tr -d " ")

newPWD="${PWD}"
newPWD="$(echo -n ${PWD} | sed -e "s|$HOME|\~|")"

pwdSurroundColor=$LIGHT_BLUE
if [ ! -w ${PWD} ]; then
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

let pwdsize=$(echo -n ${newPWD} | wc -c | tr -d " ")
let promptsize=$(echo -n "--(${usernam}@${newPWD})---(${gitBranch})--" | wc -c | tr -d " ")
let fillsize=${TERMWIDTH}-${promptsize}

fill=""
while [ "$fillsize" -gt "0" ]
do
   fill="${fill}-===--===-"
   let fillsize=${fillsize}-10
done

if [ "$fillsize" -lt "0" ]
	then

	let cut=0-${fillsize}
	fill="$(echo -n $fill | sed -e "s/\(^.\{$cut\}\)\(.*\)/\2/")"

fi


if [ $EXIT_STATUS -ne 0 ]
	then
	EXIT_SMILEY="$RED:("
else
	EXIT_SMILEY="$GREEN:)"
fi

PS1="$CYAN_BOLD-$pwdSurroundColor-(\
$CYAN\${usernam}$LIGHT_BLUE@$CYAN\${newPWD}\
${pwdSurroundColor})-${CYAN_BOLD}-\${fill}${LIGHT_BLUE}-(\
$GITCOLOR\${gitBranch}\
$LIGHT_BLUE)-$CYAN_BOLD-\
\n\
$CYAN_BOLD-$LIGHT_BLUE-($CYAN$EXIT_SMILEY$LIGHT_BLUE)-$CYAN_BOLD-:$NO_COLOUR "

}

PROMPT_COMMAND=prompt

# Setup hstr
export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"   # mem/file sync
# if this is interactive shell, then bind hh to Ctrl-r (for Vi mode check doc)
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

# for cdgit, autocompletes the directories under the github base
function _autoComplete_cdgit() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    #@ TODO variable
    COMPREPLY=( $(compgen -W '$(\ls $GITHOME/)' -- $cur) )
}
complete -F _autoComplete_cdgit cdgit

# Adds in a ton of autocompletes for bash
if [ -f $LOCALBIN/bash_completion ]; then
     . $LOCALBIN/bash_completion
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

if [ -f "$HOME/.local_profile" ]; then
  source "$HOME/.local_profile"
fi

if ! [[ "$TERM" = "screen-256color" ]] && ! [[ -n "$TMUX" ]]; then
  tmux
fi
