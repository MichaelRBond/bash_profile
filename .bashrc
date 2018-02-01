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

# Set emacs as default system editor
export EDITOR=emacs

###############################################################################
# Aliases

# Add color to ls command
alias ls='ls --color'

case $OSTYPE in
  linux*)
    # Reset HiDPI settings
    alias resetScreen='xrandr -s 0 --dpi 192XSX'

    # use htop instead of top
    alias top='htop'
    
    # Load tmux with linux config
    alias tmux="tmux -f ~/.tmux/configs/tmux.linux.conf"
    ;;
  darwin*)
    # Flush the DNS cache / reload /etc/hosts
    alias flushDNS='dscacheutil -flushcache'

    # Remove cache files to speed up terminal
    alias cleanup='sudo rm -f /private/var/log/asl/*.asl'

    # Filemerge tool
    alias filemerge="open /Applications/Xcode.app/Contents/Applications/FileMerge.app/"

    # Load tmux with Mac config
    alias tmux="tmux -f ~/.tmux/configs/tmux.mac.conf"
    ;;
  *) ;;
esac

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
newPWD="$(echo -n ${PWD} | sed -e "s/\/Users\/mbond/\~/")"

gitBranch=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
if [[ -z $gitBranch ]]; then
  gitBranch=$(date +%H:%M);
  GITCOLOR=$CYAN;
else
	GITCOLOR=$YELLOW;
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

PS1="$CYAN_BOLD-$LIGHT_BLUE-(\
$CYAN\${usernam}$LIGHT_BLUE@$CYAN\${newPWD}\
${LIGHT_BLUE})-${CYAN_BOLD}-\${fill}${LIGHT_BLUE}-(\
$GITCOLOR\${gitBranch}\
$LIGHT_BLUE)-$CYAN_BOLD-\
\n\
$CYAN_BOLD-$LIGHT_BLUE-($CYAN$EXIT_SMILEY$LIGHT_BLUE)-$CYAN_BOLD-:$NO_COLOUR "

}

PROMPT_COMMAND=prompt

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
