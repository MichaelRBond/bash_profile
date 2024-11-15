#!/bin/bash

if ! [ -x "$(command -v brew)" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

declare -a arr=(
    "alacritty"
    "awscli"
    "bash"
    "bash-completion"
    "difftastic"
    "direnv"
    "duf"
    "dust"
    "emacs"
    "git"
    "gnupg"
    "gnutls"
    "grep"
    "hstr"
    "jq"
    "just"
    "lazygit"
    "lsd"
    "midnight-commander"
    "pnpm"
    "pyenv"
    "pyenv-virtualenv"
    "shellcheck"
    "the_silver_searcher"
    "tfenv"
    "virtualenv"
    "wget"
    "yarn"
    "zellij"
    "tmux"
)

## now loop through the above array
for i in "${arr[@]}"
do
   brew list "${i}" > /dev/null 2>&1 || brew install ${i}
done

if ! [ -d "${HOME}/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

if ! [ -d "${HOME}/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
fi

GIT_SETUP_DIRECTORY="${HOME}/Documents/z.setup"
GIT_BASH_PROFILE="${GIT_SETUP_DIRECTORY}/bash_profile"
mkdir -p "${GIT_SETUP_DIRECTORY}"
if ! [ -d "${GIT_BASH_PROFILE}" ]; then
    cd "${GIT_SETUP_DIRECTORY}" || exit
    git clone https://github.com/MichaelRBond/bash_profile.git
else
    cd "${GIT_BASH_PROFILE}" || exit
    git pull
fi

rm -rf "${HOME}/.bash_profile"
rm -rf "${HOME}/.bashrc"
rm -rf "${HOME}/.splashes"
rm -rf "${HOME:?}/bin"
rm -rf "${HOME}/.config/alacritty"
rm -rf "${HOME}/.config/zellij"
ln -s "${GIT_BASH_PROFILE}/.bash_profile" "${HOME}/.bash_profile"
ln -s "${GIT_BASH_PROFILE}/.bashrc" "${HOME}/.bashrc"
ln -s "${GIT_BASH_PROFILE}/.splashes" "${HOME}/.splashes"
ln -s "${GIT_BASH_PROFILE}/bin" "${HOME}/bin"
ln -s "${GIT_BASH_PROFILE}/.config/alacritty" "${HOME}/.config/alacritty"
ln -s "${GIT_BASH_PROFILE}/.config/zellij" "${HOME}/.config/zellij"

# Setup bash
if [ -z $(grep "/opt/homebrew/bin/bash" /etc/shells) ]; then
    echo "/opt/homebrew/bin/bash" | sudo tee -a /etc/shells
fi

chsh -s /opt/homebrew/bin/bash

mkdir -p ~/Documents/GIT
