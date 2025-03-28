bash_profile
============

Same basic .bashrc has been in use since the mid 1990s.

Supports both Linux and MacOS

* Startup splash screens
* custom prompt, with basic git support
* tmux configuration
* Aliases


## The follow software is expected

### Mac

Run `setup.sh` to install all of the expected requirements and software. 
After vscode is installed, with the command line integration, run the script in the `vscode` folder to install settings and extensions. 

Manual Mac application installs: 

* vscode
* Jetbrains Mono Nerd Font: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
* 1password
* arc
* slack
* signal
* gitkraken
* ms teams
* ms word
* ms excel
* data grip
* intellij
* transmit
* moom
* zoom

### Linux

I haven't tested this on linux since switching to zellij from tmux. 

* tmux
  * TMUX Plugins
    * `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
    * `git clone https://github.com/catppuccin/tmux.git ~/.tmux/plugins/tmux`
* exa - ls replacement
* htop - top replacement
* [hh - hstr](https://github.com/dvorka/hstr) - bash history
* [mdcat](https://github.com/lunaryorn/mdcat)
* [direnv](https://direnv.net)
* [duf](https://github.com/muesli/duf)
* [dust](https://github.com/bootandy/dust)
* [ctop](https://github.com/bcicen/ctop) - Top for Containers
* [bottom](https://github.com/ClementTsang/bottom) - Graphical system monitor

### Linux

1. [xclip](https://github.com/astrand/xclip) -- For copy/Paste in tmux

### Mac

Required for tmux, not needed for zellij

1. reattach-to-user-namespace
