function fish_prompt --description 'Custom fish prompt with Catppuccin Mocha colors'
    # Save the status of the last command
    set -l last_status $status
    
    # Catppuccin Mocha colors
    set -l blue 89b4fa
    set -l green a6e3a1
    set -l red f38ba8
    set -l yellow f9e2af
    set -l pink f38ba8
    set -l teal 94e2d5
    set -l text cdd6f4
    set -l surface0 313244
    
    # User and hostname
    if test "$USER" = "root"
        set_color $red
    else
        set_color $teal
    end
    echo -n "$USER"
    
    set_color $text
    echo -n "@"
    
    set_color $green
    echo -n (prompt_hostname)
    
    # Current directory
    set_color $text
    echo -n " in "
    
    set_color $blue
    echo -n (prompt_pwd)
    
    # Git status (if in a git repository)
    if command -v git > /dev/null
        set -l git_branch (git branch --show-current 2>/dev/null)
        if test -n "$git_branch"
            set_color $text
            echo -n " on "
            
            set_color $pink
            echo -n "git:"
            set_color $yellow
            echo -n "$git_branch"
            
            # Git status indicators
            if not git diff-index --quiet HEAD -- 2>/dev/null
                set_color $red
                echo -n " ✗"
            else
                set_color $green
                echo -n " ✓"
            end
        end
    end
    
    # Command status
    if test $last_status -ne 0
        set_color $red
        echo -n " [$last_status]"
    end
    
    # Prompt character
    echo
    if test "$USER" = "root"
        set_color $red
        echo -n "# "
    else
        set_color $blue
        echo -n "❯ "
    end
    
    set_color normal
end 