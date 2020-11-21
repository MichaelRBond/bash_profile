Remove the application launchers for `super+[1..9]`

cat remove-application-key-bindings.txt | dconf load /org/gnome/shell/keybindings/
