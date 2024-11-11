#!/usr/bin/env bash

SETTINGS_FILE="${HOME}/Library/Application Support/Code/User/settings.json"
KEYBINDINGS_FILE="${HOME}/Library/Application Support/Code/User/keybindings.json"
rm -f "${SETTINGS_FILE}"
rm -f "${KEYBINDINGS_FILE}"
ln -s "${HOME}/Documents/z.setup/bash_profile/vscode/settings.json" "${SETTINGS_FILE}"
ln -s "${HOME}/Documents/z.setup/bash_profile/vscode/keybindings.json" "${KEYBINDINGS_FILE}"

code --install-extension bluebrown.yamlfmt
code --install-extension davidanson.vscode-markdownlint
code --install-extension editorconfig.editorconfig
code --install-extension enkia.tokyo-night
code --install-extension github.copilot
code --install-extension github.copilot-chat
code --install-extension github.vscode-github-actions
code --install-extension inferrinizzard.prettier-sql-vscode
code --install-extension marp-team.marp-vscode
code --install-extension ms-python.debugpy
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-toolsai.jupyter
code --install-extension ms-toolsai.jupyter-keymap
code --install-extension ms-toolsai.jupyter-renderers
code --install-extension ms-toolsai.vscode-jupyter-cell-tags
code --install-extension ms-toolsai.vscode-jupyter-slideshow
code --install-extension redhat.vscode-yaml
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension timonwong.shellcheck
code --install-extension wayou.vscode-todo-highlight
