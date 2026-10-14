# Learn fish: ~/dotfiles/docs/fish.md
set -g fish_greeting
fish_add_path ~/.local/bin

if status is-interactive
    starship init fish | source
    abbr -a ll 'ls -lah'
    abbr -a gs 'git status'
    abbr -a gd 'git diff'
    abbr -a gl 'git log --oneline -15'
    abbr -a gc 'git commit'
    abbr -a .. 'cd ..'
    abbr -a rice 'cd ~/dotfiles'
    abbr -a theme '~/dotfiles/wallpaper/wallpaper.sh'
end
