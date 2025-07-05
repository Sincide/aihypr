# Fish Shell Color Configuration - Catppuccin Mocha
# This file contains all color definitions for the fish shell

# Catppuccin Mocha Color Palette
set -l rosewater f5e0dc
set -l flamingo f2cdcd
set -l pink f38ba8
set -l mauve cba6f7
set -l red f38ba8
set -l maroon eba0ac
set -l peach fab387
set -l yellow f9e2af
set -l green a6e3a1
set -l teal 94e2d5
set -l sky 89dceb
set -l sapphire 74c7ec
set -l blue 89b4fa
set -l lavender b4befe
set -l text cdd6f4
set -l subtext1 bac2de
set -l subtext0 a6adc8
set -l overlay2 9399b2
set -l overlay1 7f849c
set -l overlay0 6c7086
set -l surface2 585b70
set -l surface1 45475a
set -l surface0 313244
set -l base 1e1e2e
set -l mantle 181825
set -l crust 11111b

# Fish color variables
set -g fish_color_autosuggestion $overlay0
set -g fish_color_cancel $red
set -g fish_color_command $blue
set -g fish_color_comment $overlay0
set -g fish_color_cwd $yellow
set -g fish_color_cwd_root $red
set -g fish_color_end $peach
set -g fish_color_error $red
set -g fish_color_escape $pink
set -g fish_color_history_current $blue
set -g fish_color_host $green
set -g fish_color_host_remote $red
set -g fish_color_keyword $pink
set -g fish_color_match $blue
set -g fish_color_normal $text
set -g fish_color_operator $pink
set -g fish_color_option $green
set -g fish_color_param $mauve
set -g fish_color_quote $green
set -g fish_color_redirection $pink
set -g fish_color_search_match --background=$surface0
set -g fish_color_selection --background=$surface0
set -g fish_color_status $red
set -g fish_color_user $teal
set -g fish_color_valid_path --underline

# Pager colors
set -g fish_pager_color_background
set -g fish_pager_color_completion $text
set -g fish_pager_color_description $overlay0
set -g fish_pager_color_prefix $pink
set -g fish_pager_color_progress $overlay0
set -g fish_pager_color_secondary_background
set -g fish_pager_color_secondary_completion $subtext0
set -g fish_pager_color_secondary_description $overlay1
set -g fish_pager_color_secondary_prefix $overlay1
set -g fish_pager_color_selected_background $surface0
set -g fish_pager_color_selected_completion $text
set -g fish_pager_color_selected_description $peach
set -g fish_pager_color_selected_prefix $pink

# Vi mode colors
set -g fish_color_mode_default $text
set -g fish_color_mode_insert $blue
set -g fish_color_mode_replace $red
set -g fish_color_mode_visual $pink

# Syntax highlighting colors
set -g fish_color_builtin $peach
set -g fish_color_function $blue
set -g fish_color_variable $mauve

# Git colors (for git prompt)
set -g __fish_git_prompt_showdirtystate 'yes'
set -g __fish_git_prompt_showuntrackedfiles 'yes'
set -g __fish_git_prompt_showstashstate 'yes'
set -g __fish_git_prompt_showupstream 'auto'

set -g __fish_git_prompt_color_branch $blue
set -g __fish_git_prompt_color_upstream_ahead $green
set -g __fish_git_prompt_color_upstream_behind $red
set -g __fish_git_prompt_color_dirtystate $red
set -g __fish_git_prompt_color_stagedstate $yellow
set -g __fish_git_prompt_color_untrackedfiles $red
set -g __fish_git_prompt_color_stashstate $blue

# Git prompt characters
set -g __fish_git_prompt_char_dirtystate '✗'
set -g __fish_git_prompt_char_stagedstate '✓'
set -g __fish_git_prompt_char_untrackedfiles '?'
set -g __fish_git_prompt_char_stashstate '⚑'
set -g __fish_git_prompt_char_upstream_ahead '⬆'
set -g __fish_git_prompt_char_upstream_behind '⬇'

# LS colors (for ls command)
set -gx LS_COLORS "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:"

# Terminal colors for various tools
set -gx TERM xterm-256color
set -gx COLORTERM truecolor

# Grep colors
set -gx GREP_COLOR "1;31"
set -gx GREP_COLORS "mt=1;31:fn=1;32:ln=1;36:bn=1;36:se=1;30"

# Less colors
set -gx LESS_TERMCAP_mb (printf "\033[1;31m")     # begin blinking
set -gx LESS_TERMCAP_md (printf "\033[1;36m")     # begin bold
set -gx LESS_TERMCAP_me (printf "\033[0m")        # end mode
set -gx LESS_TERMCAP_se (printf "\033[0m")        # end standout-mode
set -gx LESS_TERMCAP_so (printf "\033[1;44;33m")  # begin standout-mode
set -gx LESS_TERMCAP_ue (printf "\033[0m")        # end underline
set -gx LESS_TERMCAP_us (printf "\033[1;32m")     # begin underline

# Man page colors
set -gx MANPAGER "less -R --use-color -Dd+r -Du+b"

# Color output for various commands
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# Export colors for applications that support it
set -gx CLICOLOR 1
set -gx CLICOLOR_FORCE 1 