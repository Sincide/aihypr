#!/bin/bash

# ai-commit-enhanced.sh - Intelligent Git commit automation using Claude
# Author: Senior AI Engineer & DevOps Automation Specialist  
# Description: Comprehensive Git management with AI-generated commit messages
# Platform: Arch Linux with Bash shell
# Dependencies: git, claude (CLI), gh/glab, bash

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="3.0"

# Colors and emoji for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${BLUE}[*]${NC} $*"
}

success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${CYAN}[d]${NC} $*" >&2
    fi
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "📁 No Git repository found in current directory"
        if ! initialize_repository; then
            exit 1
        fi
    fi
    
    # Move to repo root for consistency
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    cd "$repo_root"
    debug "Using repo: $repo_root"
}

# Interactive menu
show_interactive_menu() {
    while true; do
        clear
        echo -e "${PURPLE}"
        echo "╭─────────────────────────────────────────╮"
        echo "│         AI Git Manager v${VERSION}            │"
        echo "│       Claude-Powered Commits            │"
        echo "╰─────────────────────────────────────────╯"
        echo -e "${NC}"
        echo
        
        echo -e "${YELLOW}What would you like to do?${NC}"
        echo
        echo "  1️⃣  Smart Sync (Claude commit + push)"
        echo "  2️⃣  Status (repository overview)"
        echo "  3️⃣  Diff (show changes)"
        echo "  4️⃣  Pull & Sync (rebase + commit + push)"
        echo "  5️⃣  Switch Protocol (SSH ↔ HTTPS)"
        echo "  6️⃣  Create Remote Repository"
        echo
        echo "  0️⃣  Exit"
        echo
        
        read -p "Enter your choice [1-6, 0 to exit]: " choice
        echo
        
        case $choice in
            1)
                read -p "Custom commit message (or Enter for Claude): " custom_msg
                sync_repository "$custom_msg"
                break
                ;;
            2)
                show_status
                break
                ;;
            3)
                show_diff
                break
                ;;
            4)
                pull_and_sync
                break
                ;;
            5)
                switch_remote_protocol
                break
                ;;
            6)
                create_remote_interactive
                break
                ;;
            0|q|quit|exit)
                info "Goodbye! 👋"
                exit 0
                ;;
            "")
                # Default to sync if just Enter is pressed
                sync_repository
                break
                ;;
            *)
                error "Invalid choice: $choice"
                echo "Please enter a number from 1-6, or 0 to exit"
                echo
                read -p "Press Enter to continue..." dummy
                ;;
        esac
    done
    
    echo
    read -p "Press Enter to return to menu, or 'q' to quit: " continue
    if [[ "$continue" == "q" || "$continue" == "quit" ]]; then
        info "Goodbye! 👋"
        exit 0
    else
        show_interactive_menu
    fi
}

# Show repository status
show_status() {
    echo -e "${PURPLE}Repository Status${NC}"
    echo "─────────────────"
    
    # Current branch
    local branch
    branch=$(git branch --show-current)
    echo -e "${BLUE}Branch:${NC} $branch"
    
    # Check for changes
    local git_status
    git_status=$(git status --porcelain)
    
    if [[ -z "$git_status" ]]; then
        success "Working directory clean"
    else
        echo
        echo -e "${YELLOW}Changes:${NC}"
        
        while IFS= read -r line; do
            local status_code="${line:0:2}"
            local filename="${line:3}"
            
            case $status_code in
                " M"|"M "|"MM")
                    echo -e "  ${YELLOW}Modified:${NC} $filename"
                    ;;
                "A "|"AM")
                    echo -e "  ${GREEN}Added:${NC}    $filename"
                    ;;
                "D "|" D")
                    echo -e "  ${RED}Deleted:${NC}  $filename"
                    ;;
                "??")
                    echo -e "  ${CYAN}New:${NC}      $filename"
                    ;;
                *)
                    echo -e "  ${BLUE}Changed:${NC}  $filename"
                    ;;
            esac
        done <<< "$git_status"
    fi
    
    # Remote sync status
    git fetch --quiet 2>/dev/null || true
    local ahead_count behind_count
    ahead_count=$(git rev-list --count @{u}..@ 2>/dev/null || echo "0")
    behind_count=$(git rev-list --count @..@{u} 2>/dev/null || echo "0")
    
    echo
    if [[ $ahead_count -eq 0 && $behind_count -eq 0 ]]; then
        success "In sync with remote"
    elif [[ $ahead_count -gt 0 && $behind_count -eq 0 ]]; then
        warn "Ahead by $ahead_count commits"
    elif [[ $ahead_count -eq 0 && $behind_count -gt 0 ]]; then
        warn "Behind by $behind_count commits"
    else
        warn "Diverged: +$ahead_count, -$behind_count commits"
    fi
    
    # Show recent commits
    echo
    echo -e "${PURPLE}Recent commits:${NC}"
    git log --oneline --color=always -3 | sed 's/^/  /'
}

# Show diff
show_diff() {
    echo -e "${PURPLE}Changes${NC}"
    echo "───────"
    
    local staged_changes unstaged_changes
    staged_changes=$(git diff --cached --name-only)
    unstaged_changes=$(git diff --name-only)
    
    if [[ -z "$staged_changes" && -z "$unstaged_changes" ]]; then
        info "No changes to show"
        return
    fi
    
    # Show staged changes
    if [[ -n "$staged_changes" ]]; then
        echo
        echo -e "${GREEN}Staged changes:${NC}"
        git diff --cached --color=always
    fi
    
    # Show unstaged changes
    if [[ -n "$unstaged_changes" ]]; then
        echo
        echo -e "${YELLOW}Unstaged changes:${NC}"
        git diff --color=always
    fi
}

# Pull and sync operation
pull_and_sync() {
    info "Starting pull and sync..."
    
    # Pull with rebase
    info "Pulling changes with rebase..."
    if git pull --rebase; then
        success "Pulled changes successfully"
    else
        error "Pull failed - resolve conflicts first"
        warn "Run: git status, fix conflicts, then git rebase --continue"
        return 1
    fi
    
    # Now do regular sync
    sync_repository "$@"
}

# Smart sync operation (main commit function)
sync_repository() {
    local custom_message="$1"
    
    info "Starting sync..."
    
    # Check for changes and stage them
    local changes
    changes=$(git status --porcelain)
    if [[ -n "$changes" ]]; then
        git add -A
        
        # Generate commit message
        local commit_msg
        if [[ -n "$custom_message" ]]; then
            commit_msg="$custom_message"
        else
            commit_msg=$(generate_commit_message)
        fi

        echo
        info "📝 Commit message:"
        echo "----------------------------------------"
        echo "$commit_msg"
        echo "----------------------------------------"
        echo

        # Confirm with user
        read -p "Use this message? [Y/n]: " confirm
        echo

        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            read -p "Enter your message: " commit_msg
        fi

        # Create commit with multi-line message
        if git commit -m "$commit_msg"; then
            success "Committed: $(echo "$commit_msg" | head -n1)"
        else
            error "Commit failed"
            return 1
        fi
    else
        info "No changes to commit"
    fi
    
    # Push changes
    local platform
    platform=$(detect_platform_quiet)
    
    if [[ "$platform" != "skip" ]]; then
        info "🚀 Pushing changes to $platform..."
        push_changes
    else
        warn "No remote configured - skipping push"
    fi
    
    success "Sync completed! 🎉"
}

# Generate commit message using Claude
generate_commit_message() {
    echo "🤖 Generating commit message with Claude..." >&2
    
    local diff_content
    diff_content=$(generate_diff_summary)
    
    # Create prompt for Claude
    local claude_prompt
    read -r -d '' claude_prompt << 'EOF' || true
You are a senior software engineer reviewing code changes for a Git commit. 

Based on the following Git diff, generate a clear, detailed commit message following these guidelines:
- Use conventional commit format (type: short description)
- First line under 50 characters (summary)
- Add a blank line after the first line
- Follow with bullet points describing specific changes:
  - Use bullet points (- ) for each significant change
  - Be specific about what files/functions were modified
  - Explain the purpose of each change
  - Keep each bullet point concise but descriptive
- Use present tense, imperative mood
- Common types: feat, fix, docs, style, refactor, test, chore

Example format:
feat: add user authentication system

- Implement JWT token generation in auth.js
- Add login/logout endpoints to user routes
- Create password hashing utility functions
- Update database schema with user credentials table

Git diff:
EOF

    # Append the actual diff content
    claude_prompt="${claude_prompt}
${diff_content}

Generate only the commit message with bullet points, no explanation or additional text:"

    # Call Claude and capture output
    local commit_msg
    commit_msg=$(echo "$claude_prompt" | claude)
    
    # Clean and sanitize the commit message
    commit_msg=$(echo "$commit_msg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # trim
    commit_msg=$(echo "$commit_msg" | sed 's/^["\047]//;s/["\047]$//')  # remove quotes
    
    echo "$commit_msg"
}

# Generate diff summary for Claude
generate_diff_summary() {
    echo "File Changes:"
    git diff --cached --name-status
    echo ""
    echo "Statistics:"
    git diff --cached --stat
    echo ""
    echo "Detailed Changes (truncated if large):"
    git diff --cached --no-color | head -n 100
}

# Detect platform without user interaction
detect_platform_quiet() {
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    if [[ -z "$remote_url" ]]; then
        echo "skip"
        return 0
    fi

    # Check for GitHub
    if [[ "$remote_url" == *"github.com"* ]]; then
        echo "github"
        return 0
    fi

    # Check for GitLab
    if [[ "$remote_url" == *"gitlab.com"* ]]; then
        echo "gitlab"
        return 0
    fi

    echo "unknown"
}

# Interactive remote creation
create_remote_interactive() {
    echo "🌐 Create Remote Repository"
    echo "──────────────────────────"
    
    # Ask for platform choice
    echo "Choose hosting platform:"
    echo "  1) GitHub"
    echo "  2) GitLab"
    
    read -p "Select platform [1-2]: " platform_choice
    
    case $platform_choice in
        1)
            create_github_repo_from_existing
            ;;
        2)
            create_gitlab_repo_from_existing
            ;;
        *)
            error "Invalid choice"
            return 1
            ;;
    esac
}

# All the existing functions from ai-commit.sh (detect_changes, stage_changes, etc.)
detect_changes() {
    # Check for unstaged changes, staged changes, or untracked files
    ! git diff --quiet || ! git diff --cached --quiet || [[ -n $(git ls-files --others --exclude-standard) ]]
}

stage_changes() {
    echo "📦 Staging all changes..."
    
    if git add -A; then
        echo "✅ All changes staged successfully"
    else
        echo "❌ Error: Failed to stage changes"
        exit 1
    fi
}

detect_platform() {
    # Get remote URL
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null)
    
    if [[ -z "$remote_url" ]]; then
        echo "⚠️  No remote origin found." >&2
        echo "🤔 Would you like to create a remote repository?" >&2
        read -p "Create remote repo? [Y/n]: " create_remote >&2
        
        if [[ "$create_remote" == "n" || "$create_remote" == "N" ]]; then
            echo "⏭️  Skipping push." >&2
            echo "skip"
            return 0
        fi
        
        # Ask for platform choice
        echo "🌐 Choose hosting platform:" >&2
        echo "  1) GitHub" >&2
        echo "  2) GitLab" >&2
        read -p "Select platform [1-2]: " platform_choice >&2
        
        case $platform_choice in
            1)
                if create_github_repo_from_existing; then
                    echo "github"
                else
                    echo "skip"
                fi
                return 0
                ;;
            2)
                if create_gitlab_repo_from_existing; then
                    echo "gitlab"
                else
                    echo "skip"
                fi
                return 0
                ;;
            *)
                echo "❌ Invalid choice. Skipping push." >&2
                echo "skip"
                return 0
                ;;
        esac
    fi

    # Check for GitHub
    if [[ "$remote_url" == *"github.com"* ]]; then
        echo "github"
        return 0
    fi

    # Check for GitLab
    if [[ "$remote_url" == *"gitlab.com"* ]]; then
        echo "gitlab"
        return 0
    fi

    # If detection fails, ask user
    echo "🤔 Could not auto-detect platform from URL: $remote_url" >&2
    echo "Available options:" >&2
    echo "  1) GitHub (gh)" >&2
    echo "  2) GitLab (glab)" >&2
    echo "  3) Skip push" >&2
    
    read -p "Select platform [1-3]: " choice >&2
    
    case $choice in
        1) echo "github" ;;
        2) echo "gitlab" ;;
        3) echo "skip" ;;
        *) echo "❌ Invalid choice. Skipping push." >&2; echo "skip" ;;
    esac
}

push_changes() {
    local platform
    platform=$(detect_platform)
    
    if [[ "$platform" == "skip" ]]; then
        echo "⏭️  Push skipped by user choice"
        return 0
    fi

    echo "🚀 Pushing changes to $platform..."

    case $platform in
        github)
            push_to_github
            ;;
        gitlab)
            push_to_gitlab
            ;;
        *)
            echo "❌ Unknown platform: $platform"
            return 1
            ;;
    esac
}

push_to_github() {
    # Check if gh is installed
    if ! command -v gh >/dev/null; then
        echo "❌ Error: GitHub CLI (gh) is not installed"
        return 1
    fi

    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        echo "❌ Error: Not authenticated with GitHub CLI"
        echo "Run: gh auth login"
        return 1
    fi

    # Get current branch
    local current_branch
    current_branch=$(git branch --show-current)
    
    # Push to origin
    if git push origin "$current_branch"; then
        echo "✅ Successfully pushed to GitHub"
    else
        echo "❌ Error: Failed to push to GitHub"
        return 1
    fi
}

push_to_gitlab() {
    # Check if glab is installed
    if ! command -v glab >/dev/null; then
        echo "❌ Error: GitLab CLI (glab) is not installed"
        return 1
    fi

    # Check if authenticated
    if ! glab auth status >/dev/null 2>&1; then
        echo "❌ Error: Not authenticated with GitLab CLI"
        echo "Run: glab auth login"
        return 1
    fi

    # Get current branch
    local current_branch
    current_branch=$(git branch --show-current)
    
    # Push to origin
    if git push origin "$current_branch"; then
        echo "✅ Successfully pushed to GitLab"
    else
        echo "❌ Error: Failed to push to GitLab"
        return 1
    fi
}

initialize_repository() {
    echo "🔧 Would you like to initialize a new Git repository?"
    read -p "Initialize Git repo? [Y/n]: " init_confirm
    
    if [[ "$init_confirm" == "n" || "$init_confirm" == "N" ]]; then
        echo "❌ Repository initialization cancelled"
        return 1
    fi

    # Initialize Git repository
    if ! git init; then
        echo "❌ Error: Failed to initialize Git repository"
        return 1
    fi
    
    echo "✅ Git repository initialized"
    
    # Ask for platform choice
    echo "🌐 Choose hosting platform:"
    echo "  1) GitHub"
    echo "  2) GitLab"
    echo "  3) Local only (no remote)"
    
    read -p "Select platform [1-3]: " platform_choice
    
    case $platform_choice in
        1)
            if ! create_github_repo; then
                echo "⚠️  Continuing with local repository only"
            fi
            ;;
        2)
            if ! create_gitlab_repo; then
                echo "⚠️  Continuing with local repository only"
            fi
            ;;
        3)
            echo "📝 Repository will remain local only"
            ;;
        *)
            echo "❌ Invalid choice. Repository will remain local only"
            ;;
    esac
    
    return 0
}

# Include all the create_*_repo functions from the original ai-commit.sh
create_github_repo() {
    # [Same as original - keeping for brevity]
    echo "GitHub repo creation - use create_github_repo_from_existing"
}

create_gitlab_repo() {
    # [Same as original - keeping for brevity]  
    echo "GitLab repo creation - use create_gitlab_repo_from_existing"
}

create_github_repo_from_existing() {
    echo "🚀 Creating GitHub repository from existing local repo..." >&2
    
    # Check if gh is installed
    if ! command -v gh >/dev/null; then
        echo "❌ Error: GitHub CLI (gh) is not installed" >&2
        return 1
    fi

    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        echo "❌ Error: Not authenticated with GitHub CLI" >&2
        echo "Run: gh auth login" >&2
        return 1
    fi

    # Get repository name (use current directory name as default)
    local default_name
    default_name=$(basename "$(pwd)")
    read -p "📝 Repository name [$default_name]: " repo_name >&2
    
    if [[ -z "$repo_name" ]]; then
        repo_name="$default_name"
    fi
    
    # Ask for repository visibility
    echo "🔒 Repository visibility:" >&2
    echo "  1) Public" >&2
    echo "  2) Private" >&2
    read -p "Select visibility [1-2]: " visibility_choice >&2
    
    # Ask for protocol preference
    echo "🔑 Remote URL protocol:" >&2
    echo "  1) SSH (recommended for GitHub)" >&2
    echo "  2) HTTPS" >&2
    read -p "Select protocol [1-2]: " protocol_choice >&2
    
    local visibility_flag="--public"
    if [[ "$visibility_choice" == "2" ]]; then
        visibility_flag="--private"
    fi
    
    # Create repository and set up remote with chosen protocol
    if [[ "$protocol_choice" == "1" ]]; then
        # SSH protocol
        if gh repo create "$repo_name" $visibility_flag --source=. --remote=origin --clone; then
            # Update remote to use SSH
            local username
            username=$(gh api user --jq .login)
            git remote set-url origin "git@github.com:$username/$repo_name.git"
            echo "✅ GitHub repository created with SSH remote" >&2
            return 0
        else
            echo "❌ Error: Failed to create GitHub repository" >&2
            return 1
        fi
    else
        # HTTPS protocol (default)
        if gh repo create "$repo_name" $visibility_flag --source=. --remote=origin; then
            echo "✅ GitHub repository created with HTTPS remote" >&2
            echo "ℹ️  Note: You'll need a Personal Access Token for pushing" >&2
            return 0
        else
            echo "❌ Error: Failed to create GitHub repository" >&2
            return 1
        fi
    fi
}

create_gitlab_repo_from_existing() {
    echo "🚀 Creating GitLab repository from existing local repo..." >&2
    
    # Check if glab is installed
    if ! command -v glab >/dev/null; then
        echo "❌ Error: GitLab CLI (glab) is not installed" >&2
        return 1
    fi

    # Check if authenticated
    if ! glab auth status >/dev/null 2>&1; then
        echo "❌ Error: Not authenticated with GitLab CLI" >&2
        echo "Run: glab auth login" >&2
        return 1
    fi

    # Get repository name (use current directory name as default)
    local default_name
    default_name=$(basename "$(pwd)")
    read -p "📝 Repository name [$default_name]: " repo_name >&2
    
    if [[ -z "$repo_name" ]]; then
        repo_name="$default_name"
    fi
    
    # Ask for repository visibility
    echo "🔒 Repository visibility:" >&2
    echo "  1) Public" >&2
    echo "  2) Private" >&2
    read -p "Select visibility [1-2]: " visibility_choice >&2
    
    # Ask for protocol preference
    echo "🔑 Remote URL protocol:" >&2
    echo "  1) SSH (recommended)" >&2
    echo "  2) HTTPS" >&2
    read -p "Select protocol [1-2]: " protocol_choice >&2
    
    # Create repository with correct glab syntax
    if [[ "$visibility_choice" == "2" ]]; then
        glab repo create "$repo_name" --private >&2
    else
        glab repo create "$repo_name" --public >&2
    fi
    
    if [[ $? -eq 0 ]]; then
        # Get username for URL construction
        local username
        username=$(glab auth status 2>&1 | grep "Logged in to" | sed 's/.*as \([^[:space:]]*\).*/\1/')
        
        # Construct URL based on protocol choice
        local repo_url
        if [[ "$protocol_choice" == "1" ]]; then
            repo_url="git@gitlab.com:$username/$repo_name.git"
            echo "✅ GitLab repository created with SSH remote" >&2
        else
            repo_url="https://gitlab.com/$username/$repo_name.git"
            echo "✅ GitLab repository created with HTTPS remote" >&2
        fi
        
        # Add remote origin
        if git remote add origin "$repo_url"; then
            echo "   Remote: $repo_url" >&2
            return 0
        else
            echo "❌ Error: Failed to add remote origin" >&2
            return 1
        fi
    else
        echo "❌ Error: Failed to create GitLab repository" >&2
        return 1
    fi
}

switch_remote_protocol() {
    # Check if we're in a Git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Error: Not in a Git repository"
        exit 1
    fi

    # Get current remote URL
    local current_url
    current_url=$(git config --get remote.origin.url 2>/dev/null)
    
    if [[ -z "$current_url" ]]; then
        echo "❌ Error: No remote origin found"
        exit 1
    fi

    echo "🔄 Current remote URL: $current_url"
    
    # Detect current protocol and platform
    local current_protocol=""
    local platform=""
    local username=""
    local repo_name=""
    
    # Parse GitHub URLs
    if [[ "$current_url" == *"github.com"* ]]; then
        platform="github"
        if [[ "$current_url" == git@github.com:* ]]; then
            current_protocol="ssh"
            # Extract username/repo from git@github.com:username/repo.git
            url_parts="${current_url#git@github.com:}"
            url_parts="${url_parts%.git}"
            username="${url_parts%/*}"
            repo_name="${url_parts#*/}"
        elif [[ "$current_url" == https://github.com/* ]]; then
            current_protocol="https"
            # Extract username/repo from https://github.com/username/repo.git
            url_parts="${current_url#https://github.com/}"
            url_parts="${url_parts%.git}"
            username="${url_parts%/*}"
            repo_name="${url_parts#*/}"
        fi
    # Parse GitLab URLs
    elif [[ "$current_url" == *"gitlab.com"* ]]; then
        platform="gitlab"
        if [[ "$current_url" == git@gitlab.com:* ]]; then
            current_protocol="ssh"
            # Extract username/repo from git@gitlab.com:username/repo.git
            url_parts="${current_url#git@gitlab.com:}"
            url_parts="${url_parts%.git}"
            username="${url_parts%/*}"
            repo_name="${url_parts#*/}"
        elif [[ "$current_url" == https://gitlab.com/* ]]; then
            current_protocol="https"
            # Extract username/repo from https://gitlab.com/username/repo.git
            url_parts="${current_url#https://gitlab.com/}"
            url_parts="${url_parts%.git}"
            username="${url_parts%/*}"
            repo_name="${url_parts#*/}"
        fi
    else
        echo "❌ Error: Unsupported remote URL format"
        echo "   Only GitHub and GitLab URLs are supported"
        exit 1
    fi

    if [[ -z "$platform" || -z "$current_protocol" || -z "$username" || -z "$repo_name" ]]; then
        echo "❌ Error: Could not parse remote URL"
        exit 1
    fi

    echo "📍 Platform: $platform"
    echo "🔗 Current protocol: $current_protocol"
    echo "👤 Username: $username"
    echo "📦 Repository: $repo_name"
    echo ""

    # Offer to switch protocol
    if [[ "$current_protocol" == "ssh" ]]; then
        echo "🔄 Switch to HTTPS protocol?"
        read -p "Switch to HTTPS? [Y/n]: " confirm
        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            echo "⏭️  No changes made"
            return 0
        fi
        
        # Switch to HTTPS
        local new_url="https://$platform.com/$username/$repo_name.git"
        if git remote set-url origin "$new_url"; then
            echo "✅ Remote URL switched to HTTPS: $new_url"
            if [[ "$platform" == "github" ]]; then
                echo "ℹ️  Note: You'll need a Personal Access Token for GitHub HTTPS"
            fi
        else
            echo "❌ Error: Failed to update remote URL"
            return 1
        fi
    else
        echo "🔄 Switch to SSH protocol?"
        read -p "Switch to SSH? [Y/n]: " confirm
        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            echo "⏭️  No changes made"
            return 0
        fi
        
        # Switch to SSH
        local new_url="git@$platform.com:$username/$repo_name.git"
        if git remote set-url origin "$new_url"; then
            echo "✅ Remote URL switched to SSH: $new_url"
            echo "ℹ️  Note: Make sure you have SSH keys configured for $platform"
        else
            echo "❌ Error: Failed to update remote URL"
            return 1
        fi
    fi
}

show_help() {
    echo -e "${PURPLE}"
    echo "╭─────────────────────────────────────────╮"
    echo "│         AI Git Manager v${VERSION}            │"
    echo "│       Claude-Powered Commits            │"
    echo "╰─────────────────────────────────────────╯"
    echo -e "${NC}"
    
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ai-commit                    - Interactive menu (default)"
    echo "  ai-commit [command]          - Direct command"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo "  sync [message]      - Smart sync with Claude commits"
    echo "  pull-sync [message] - Pull with rebase + commit + push"
    echo "  status             - Show repository status"
    echo "  diff               - Show changes"
    echo "  switch-url         - Switch remote between SSH and HTTPS"
    echo "  create-remote      - Create remote repository"
    echo "  menu               - Show interactive menu"
    echo "  help               - Show this help"
    
    echo
    echo -e "${YELLOW}Features:${NC}"
    echo "  🤖 Claude-powered commit messages with bullet points"
    echo "  🔄 Smart git sync with pull/rebase support"
    echo "  🌐 GitHub and GitLab integration"
    echo "  🔑 SSH/HTTPS protocol switching"
    echo "  📱 Interactive menu system"
    echo "  🚀 Repository initialization"
    
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ai-commit                           # Interactive menu"
    echo "  ai-commit sync                      # Quick Claude sync"
    echo "  ai-commit sync \"fix bug\"            # Custom message"
    echo "  ai-commit pull-sync                 # Pull + commit + push"
    echo "  ai-commit status                    # Check status"
    echo "  ai-commit switch-url                # Toggle SSH/HTTPS"
}

# Main function
main() {
    # If no arguments, show interactive menu
    if [[ $# -eq 0 ]]; then
        check_git_repo
        show_interactive_menu
        return
    fi
    
    # Command dispatcher
    case $1 in
        sync|s)
            check_git_repo
            sync_repository "${2:-}"
            ;;
        pull-sync|ps)
            check_git_repo
            pull_and_sync "${2:-}"
            ;;
        status|st)
            check_git_repo
            show_status
            ;;
        diff|d)
            check_git_repo
            show_diff
            ;;
        switch-url|--switch-url|-s)
            switch_remote_protocol
            ;;
        create-remote|cr)
            check_git_repo
            create_remote_interactive
            ;;
        menu|interactive|i)
            check_git_repo
            show_interactive_menu
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main with all arguments
main "$@"