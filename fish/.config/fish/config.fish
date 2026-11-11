# Learn fish: ~/dotfiles/docs/fish.md
# Every new shell: a wild Pokémon and a line of mathematics (~/.local/bin/rice-greet).
function fish_greeting
    rice-greet $COLUMNS
end
fish_add_path ~/.local/bin

if status is-interactive
    starship init fish | source
    zoxide init fish | source            # z NAME: jump to a folder you have been in;  zi: pick one
    fzf --fish | source                  # Ctrl+R history, Ctrl+T file, Alt+C folder

    # `rice` changed the palette: every open shell re-reads its colours
    function __rice_recolor --on-variable __rice_stamp
        source ~/.config/fish/conf.d/colors.fish
        source ~/.config/fish/conf.d/fzf.fish
    end

    # ev [words]: Everything in the terminal. Results change as you type.
    #   Enter open · Alt+Enter cd to its folder · Ctrl+O edit · Ctrl+Y copy path
    function ev --description 'live search over every file on the disk'
        set -l out (fzf --disabled --query "$argv" --delimiter '\t' --with-nth '{6} {2}' --prompt '󰈞  ' \
            --header 'pdf: img: dir: ext:rs notes/   ⏎ open  M-⏎ cd  ^O edit  ^Y copy' \
            --bind 'start:reload:evry --tsv -l 300 -- {q}' --bind 'change:reload:evry --tsv -l 300 -- {q}' \
            --preview 'rice-preview {2}' --preview-window 'right,50%' --height 100% \
            --expect 'alt-enter,ctrl-o,ctrl-y')
        test (count $out) -ge 2; or return
        set -l path (string split \t -- $out[2])[2]
        switch $out[1]
            case alt-enter
                test -d $path; or set path (path dirname $path)
                cd $path
            case ctrl-o
                nvim $path
            case ctrl-y
                printf %s $path | xclip -selection clipboard
            case '*'
                evry open $path >/dev/null 2>&1 &
                disown
        end
    end

    # fastfetch with a random Pokémon as the logo
    function pokefetch
        set -l sprite (rice-greet --path)
        if test -n "$sprite"
            fastfetch --file-raw $sprite $argv
        else
            fastfetch $argv
        end
    end

    abbr -a ls 'eza --icons --group-directories-first'
    abbr -a ll 'eza -lah --icons --git --group-directories-first'
    abbr -a lt 'eza --tree --level=2 --icons'
    abbr -a cat 'batcat'
    abbr -a gs 'git status'
    abbr -a gd 'git diff'
    abbr -a gl 'git log --oneline -15'
    abbr -a gc 'git commit'
    abbr -a .. 'cd ..'
    abbr -a dots 'cd ~/dotfiles'
    abbr -a theme 'rice'
    abbr -a pdf 'zathura'
end
