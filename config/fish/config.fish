# Fish Shell Configuration
# Main configuration file - sources modular components

# Disable fish greeting
set fish_greeting

# Source color configuration
source ~/.config/fish/colors.fish

# Environment variables
set -gx EDITOR nvim
set -gx BROWSER firefox
set -gx TERM xterm-256color
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# XDG Base Directory specification
set -gx XDG_CONFIG_HOME ~/.config
set -gx XDG_DATA_HOME ~/.local/share
set -gx XDG_CACHE_HOME ~/.cache

# Path configuration
set -gx PATH $HOME/.local/bin $HOME/bin $PATH

# Fish-specific settings
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_vi_force_cursor 1
set -g fish_cursor_default block
set -g fish_cursor_insert line
set -g fish_cursor_replace_one underscore
set -g fish_cursor_visual block

# History configuration
set -g fish_history_max 10000
set -g fish_history_duplicates erase

# Completion settings
set -g fish_complete_path $fish_complete_path ~/.config/fish/completions

# Pager settings
set -gx PAGER less
set -gx LESS -R

# FZF configuration
set -gx FZF_DEFAULT_OPTS '
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
--border=rounded
--cycle
--layout=reverse
--height=50%
--preview-window=border-rounded
--prompt="❯ "
--pointer="➤"
--marker="✓"
'

# Aliases
alias ll 'ls -la'
alias la 'ls -la'
alias l 'ls -CF'
alias grep 'grep --color=auto'
alias fgrep 'fgrep --color=auto'
alias egrep 'egrep --color=auto'
alias diff 'diff --color=auto'
alias cls 'clear'
alias mkdir 'mkdir -p'
alias cp 'cp -i'
alias mv 'mv -i'
alias rm 'rm -i'
alias ..  'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'

# Editor aliases
alias vim 'nvim'
alias vi 'nvim'
alias nano 'nvim'

# Git aliases
alias g 'git'
alias ga 'git add'
alias gc 'git commit'
alias gco 'git checkout'
alias gb 'git branch'
alias gs 'git status'
alias gd 'git diff'
alias gl 'git log'
alias gp 'git push'
alias gpl 'git pull'
alias gf 'git fetch'
alias gm 'git merge'
alias gr 'git remote'
alias gt 'git tag'
alias gst 'git stash'

# System aliases
alias df 'df -h'
alias du 'du -h'
alias free 'free -h'
alias ps 'ps aux'
alias top 'htop'
alias mount 'mount | column -t'
alias ports 'netstat -tulanp'

# Package management (Arch Linux)
alias pac 'sudo pacman -S'
alias pacu 'sudo pacman -Syu'
alias pacr 'sudo pacman -Rs'
alias pacs 'pacman -Ss'
alias paci 'pacman -Si'
alias paclo 'pacman -Qdt'
alias pacc 'sudo pacman -Scc'
alias pacorphan 'sudo pacman -Rns (pacman -Qtdq)'

# AUR helpers
alias yay 'yay --color=auto'
alias yayi 'yay -S'
alias yayu 'yay -Syu'
alias yayc 'yay -Sc'

# Abbreviations (fish-specific shortcuts)
abbr -a gc 'git commit -m'
abbr -a gca 'git commit -am'
abbr -a gcl 'git clone'
abbr -a gco 'git checkout'
abbr -a gcom 'git checkout main'
abbr -a gcod 'git checkout develop'
abbr -a gd 'git diff'
abbr -a gds 'git diff --staged'
abbr -a gl 'git log --oneline'
abbr -a gla 'git log --oneline --all --graph'
abbr -a gp 'git push'
abbr -a gpl 'git pull'
abbr -a gs 'git status'
abbr -a gst 'git stash'
abbr -a gsta 'git stash apply'
abbr -a gwip 'git add -A && git commit -m "WIP"'

# Docker abbreviations
abbr -a d 'docker'
abbr -a dc 'docker-compose'
abbr -a dcu 'docker-compose up'
abbr -a dcd 'docker-compose down'
abbr -a dcr 'docker-compose restart'
abbr -a dps 'docker ps'
abbr -a dpa 'docker ps -a'
abbr -a di 'docker images'
abbr -a drm 'docker rm'
abbr -a drmi 'docker rmi'

# Navigation abbreviations
abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'
abbr -a ..... 'cd ../../../..'
abbr -a - 'cd -'

# System abbreviations
abbr -a c 'clear'
abbr -a h 'history'
abbr -a j 'jobs'
abbr -a q 'exit'
abbr -a rf 'source ~/.config/fish/config.fish'

# Functions
function mkcd
    mkdir -p $argv[1] && cd $argv[1]
end

function extract
    if test -f $argv[1]
        switch $argv[1]
            case '*.tar.bz2'
                tar xjf $argv[1]
            case '*.tar.gz'
                tar xzf $argv[1]
            case '*.bz2'
                bunzip2 $argv[1]
            case '*.rar'
                unrar x $argv[1]
            case '*.gz'
                gunzip $argv[1]
            case '*.tar'
                tar xf $argv[1]
            case '*.tbz2'
                tar xjf $argv[1]
            case '*.tgz'
                tar xzf $argv[1]
            case '*.zip'
                unzip $argv[1]
            case '*.Z'
                uncompress $argv[1]
            case '*.7z'
                7z x $argv[1]
            case '*'
                echo "'$argv[1]' cannot be extracted via extract()"
        end
    else
        echo "'$argv[1]' is not a valid file"
    end
end

function weather
    if test (count $argv) -eq 0
        curl wttr.in
    else
        curl wttr.in/$argv[1]
    end
end

function cheat
    curl cheat.sh/$argv[1]
end

function qr
    if test (count $argv) -eq 0
        echo "Usage: qr <text>"
    else
        curl qrenco.de/$argv[1]
    end
end

# Using custom fish_prompt function instead of starship

# Zoxide (if available)
if command -v zoxide > /dev/null
    zoxide init fish | source
end

# Direnv (if available)
if command -v direnv > /dev/null
    direnv hook fish | source
end

# Auto-start X server on login (if in tty1)
if test "$TTY" = "/dev/tty1"
    exec startx
end 