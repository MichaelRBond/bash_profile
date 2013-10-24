###############################################################################
# Variables

export LOCALBIN=$HOME/bin
export GITHOME=$HOME/Documents/Dropbox/GIT
export SPLASH_SCREEN=$HOME/.splash
export PATH=$LOCALBIN:/usr/local/bin:$PATH

# Load RVM
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"


###############################################################################
# Aliases

# Remove cache files to speed up terminal
alias cleanup='sudo rm -f /private/var/log/asl/*.asl'

# Add color to ls command
alias ls='ls -G'

# Display a directory tree
alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"

# Flush the DNS cache / reload /etc/hosts
alias flushDNS='dscacheutil -flushcache'

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
echo

###############################################################################
# Prompt

LIGHT_BLUE="\[\033[0;34m\]"
CYAN_BOLD="\[\033[1;36m\]"
NO_COLOUR="\[\033[0m\]"
GREEN="\[\033[1;32m\]"
CYAN="\[\033[0;36m\]"
RED="\[\033[1;31m\]"

EXIT_SMILEY=":-/"

function prompt {

EXIT_STATUS=$?

TERMWIDTH=${COLUMNS}

usernam=$(whoami)
let usersize=$(echo -n $usernam | wc -c | tr -d " ")

newPWD="${PWD}"
newPWD="$(echo -n ${PWD} | sed -e "s/\/Users\/mbond/\~/")"

let pwdsize=$(echo -n ${newPWD} | wc -c | tr -d " ")
let promptsize=$(echo -n "--(${usernam}@${newPWD})---($(date +%H:%M))--" | wc -c | tr -d " ")
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
$CYAN\$(date +%H:%M)\
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
    COMPREPLY=( $(compgen -W '$(ls $GITHOME/)' -- $cur) )
}
complete -F _autoComplete_cdgit cdgit

# Adds in a ton of autocompletes for bash
if [ -f $LOCALBIN/bash_completion ]; then
     . $LOCALBIN/bash_completion
fi

