#!/bin/bash

# Claude Code CLI Setup Script
# Author: Martin's Dotfiles - Modular Version
# Description: Install and configure Claude Code CLI for AI-powered development

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly LOG_DIR="${DOTFILES_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/claude-code-setup_$(date +%Y%m%d_%H%M%S).log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Flags
SKIP_CONFIRMATION=false
SKIP_AUTHENTICATION=false
SKIP_UTILITIES=false
DRY_RUN=false
FORCE_REINSTALL=false

# Claude Code configuration
CLAUDE_CODE_VERSION="latest"
CLAUDE_CODE_DIR="$HOME/.claude-code"

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    echo "Starting Claude Code setup - $(date)" >> "$LOG_FILE"
    echo "[LOG] Script: $SCRIPT_NAME" >> "$LOG_FILE"
}

# Logging functions
log_info() {
    local msg="[INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}✓ $msg${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[ERROR] $1"
    echo -e "${RED}✗ $msg${NC}" >&2
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}⚠ $msg${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

log_section() {
    local msg="$1"
    echo -e "${CYAN}=== $msg ===${NC}"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [SECTION] $msg" >> "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as regular user
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root"
        exit 1
    fi
    
    # Check system requirements
    local total_ram
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 2000 ]]; then
        log_warning "Low RAM detected (${total_ram}MB). Claude Code may be slow."
    else
        log_success "Sufficient RAM detected (${total_ram}MB)"
    fi
    
    # Check for required tools
    local required_tools=("curl" "npm" "node")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install them with: sudo pacman -S ${missing_tools[*]}"
        exit 1
    fi
    
    # Check Node.js version
    local node_version
    node_version=$(node --version | sed 's/v//')
    local node_major
    node_major=$(echo "$node_version" | cut -d. -f1)
    
    if [[ $node_major -lt 18 ]]; then
        log_warning "Node.js version $node_version detected. Claude Code requires Node.js 18+."
        log_info "Consider updating Node.js"
    else
        log_success "Node.js version $node_version is compatible"
    fi
    
    # Check internet connectivity
    if ! curl -s --max-time 10 https://www.anthropic.com >/dev/null; then
        log_warning "Cannot reach Anthropic servers. Check internet connection."
    else
        log_success "Internet connectivity verified"
    fi
    
    log_success "Prerequisites check passed"
}

# Install Claude Code
install_claude_code() {
    log_section "Installing Claude Code CLI"
    
    # Check if already installed
    if command -v claude &>/dev/null && [[ "$FORCE_REINSTALL" != "true" ]]; then
        local claude_version
        claude_version=$(claude --version 2>/dev/null || echo "unknown")
        log_success "Claude Code is already installed: $claude_version"
        
        if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
            read -p "Reinstall Claude Code? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipped Claude Code installation"
                return 0
            fi
        else
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would install Claude Code CLI"
        return 0
    fi
    
    if [[ "$SKIP_CONFIRMATION" != "true" && "$FORCE_REINSTALL" != "true" ]]; then
        echo -e "${CYAN}Claude Code CLI Features:${NC}"
        echo "• AI-powered coding assistance"
        echo "• Intelligent commit message generation"
        echo "• Interactive development sessions"
        echo "• Integration with various development tools"
        echo "• Secure API key management"
        echo
        read -p "Install Claude Code CLI? (Y/n): " -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Skipped Claude Code installation"
            return 1
        fi
    fi
    
    log_info "Installing Claude Code CLI via npm..."
    
    # Install Claude Code globally
    if npm install -g @anthropic/claude-code; then
        log_success "Claude Code CLI installed successfully"
        
        # Verify installation
        sleep 2
        if command -v claude &>/dev/null; then
            local claude_version
            claude_version=$(claude --version 2>/dev/null || echo "unknown")
            log_success "Claude Code version: $claude_version"
        else
            log_error "Claude Code installation verification failed"
            return 1
        fi
    else
        log_error "Failed to install Claude Code CLI"
        log_info "Trying alternative installation method..."
        
        # Alternative: Try installing locally and linking
        if npm install @anthropic/claude-code && npm link @anthropic/claude-code; then
            log_success "Claude Code CLI installed via local installation"
        else
            log_error "All installation methods failed"
            return 1
        fi
    fi
}

# Detect if running in SSH/headless environment
detect_headless_environment() {
    local is_headless=false
    
    # Check for SSH session
    if [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]] || [[ "${SSH_CONNECTION:-}" ]]; then
        is_headless=true
    fi
    
    # Check for lack of DISPLAY (X11)
    if [[ -z "${DISPLAY:-}" ]]; then
        is_headless=true
    fi
    
    # Check if running in CI/automated environment
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${JENKINS_URL:-}" ]]; then
        is_headless=true
    fi
    
    echo "$is_headless"
}

# Configure Claude Code authentication
configure_authentication() {
    if [[ "$SKIP_AUTHENTICATION" == "true" ]]; then
        log_info "Skipping Claude Code authentication setup"
        return 0
    fi
    
    log_section "Configuring Claude Code Authentication"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would configure Claude Code authentication"
        return 0
    fi
    
    # Detect environment type
    local is_headless
    is_headless=$(detect_headless_environment)
    
    if [[ "$is_headless" == "true" ]]; then
        log_warning "Headless/SSH environment detected"
        log_info "OAuth authentication may not work without browser access"
        log_info "API key authentication is recommended for this environment"
    fi
    
    # Check if already authenticated
    if claude config list 2>/dev/null | grep -q "apiKey"; then
        log_success "Claude Code appears to be already configured"
        
        if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
            read -p "Reconfigure authentication? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipped authentication configuration"
                return 0
            fi
        else
            return 0
        fi
    fi
    
    echo -e "${CYAN}Claude Code Authentication Options:${NC}"
    echo "Choose your authentication method:"
    echo
    echo "Option 1: API Key (Recommended for headless/SSH)"
    echo "1. Go to: https://console.anthropic.com/"
    echo "2. Sign in or create an account"
    echo "3. Navigate to API Keys section"
    echo "4. Generate a new API key"
    echo "5. Copy the API key"
    echo
    echo "Option 2: Pro/Max Subscription (GUI required)"
    echo "1. Ensure you have a Claude Pro or Max subscription"
    echo "2. Run 'claude' command (requires browser access)"
    echo "3. Select subscription login when prompted"
    echo "4. Complete browser-based OAuth login"
    echo
    if [[ "$is_headless" == "true" ]]; then
        echo -e "${YELLOW}⚠️  SSH/Headless Environment Detected${NC}"
        echo "OAuth authentication requires a browser and may not work in SSH sessions."
        echo
        echo -e "${CYAN}💡 Alternative Options for Headless Authentication:${NC}"
        echo "A. Use your phone/mobile device to complete OAuth"
        echo "B. Use a text browser (lynx, elinks, w3m) if available"
        echo "C. SSH with X11 forwarding (ssh -X) if possible"
        echo "D. API key authentication (most reliable)"
        echo
    fi
    
    if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
        echo -e "${YELLOW}Which authentication method do you want to use?${NC}"
        if [[ "$is_headless" == "true" ]]; then
            echo "1) API Key (Console/PAYG) - Most reliable for headless"
            echo "2) Pro/Max OAuth via phone/mobile browser"
            echo "3) Pro/Max OAuth via text browser (lynx/elinks/w3m)"
            echo "4) Pro/Max OAuth via SSH X11 forwarding"
            echo "5) Skip authentication setup"
            echo
            echo -e "${CYAN}Recommendation: Choose option 1 (API Key) for headless/SSH environments${NC}"
            echo -e "${CYAN}Alternative: Option 2 (phone) if you have a Pro/Max subscription${NC}"
        else
            echo "1) Pro/Max Subscription (OAuth browser login)"
            echo "2) API Key (Console/PAYG)"
            echo "3) Skip authentication setup"
        fi
        echo
        read -p "Choose [1-5]: " -r auth_choice
        
        case "$auth_choice" in
            1)
                if [[ "$is_headless" == "true" ]]; then
                    # In headless mode, option 1 is API key
                    setup_api_key_auth
                else
                    # In GUI mode, option 1 is Pro/Max subscription
                    setup_subscription_auth
                fi
                ;;
            2)
                if [[ "$is_headless" == "true" ]]; then
                    # In headless mode, option 2 is phone OAuth
                    setup_phone_oauth_auth
                else
                    # In GUI mode, option 2 is API key
                    setup_api_key_auth
                fi
                ;;
            3)
                if [[ "$is_headless" == "true" ]]; then
                    # In headless mode, option 3 is text browser OAuth
                    setup_text_browser_auth
                else
                    # In GUI mode, option 3 is skip
                    skip_authentication_setup
                fi
                ;;
            4)
                if [[ "$is_headless" == "true" ]]; then
                    # In headless mode, option 4 is SSH X11 forwarding
                    setup_x11_forwarding_auth
                else
                    # In GUI mode, this shouldn't happen
                    skip_authentication_setup
                fi
                ;;
            5|*)
                if [[ "$is_headless" == "true" ]]; then
                    # In headless mode, option 5 is skip
                    skip_authentication_setup
                else
                    # In GUI mode, this shouldn't happen
                    skip_authentication_setup
                fi
                ;;
        esac
    else
        # Automated mode - try environment variable first, then skip
        if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
            log_info "Found API key in environment variable"
            if claude config set apiKey "$ANTHROPIC_API_KEY"; then
                log_success "API key configured from environment"
            else
                log_error "Failed to set API key from environment"
            fi
        else
            log_info "No authentication configured in automated mode"
            log_info "Set ANTHROPIC_API_KEY environment variable or authenticate manually later"
            return 0
        fi
    fi
}

# Setup Pro/Max subscription authentication
setup_subscription_auth() {
    log_info "Setting up Pro/Max subscription authentication..."
    log_info "Starting Claude Code - you'll be prompted to log in"
    log_info "This will open your browser for OAuth authentication"
    echo
    echo -e "${YELLOW}After running 'claude', select the subscription login option${NC}"
    echo -e "${YELLOW}Complete the browser login with your Pro/Max account${NC}"
    echo
    read -p "Ready to start Claude Code for authentication? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Starting Claude Code authentication..."
        log_info "Follow the prompts to complete OAuth login"
        # Note: We can't fully automate this as it requires browser interaction
        claude || log_warning "Authentication may need to be completed manually"
    else
        log_info "You can authenticate later by running: claude"
    fi
}

# Skip authentication setup
skip_authentication_setup() {
    log_info "Skipping authentication setup"
    log_info "You can authenticate later with one of these methods:"
    log_info "  Pro/Max users: Run 'claude' and select subscription login"
    log_info "  API users: Run 'claude config set apiKey YOUR_API_KEY'"
    return 0
}

# Setup phone OAuth authentication
setup_phone_oauth_auth() {
    log_info "Setting up Pro/Max subscription authentication via phone/mobile device..."
    echo
    echo -e "${CYAN}📱 Phone/Mobile Authentication Steps:${NC}"
    echo "1. On your phone, open a web browser"
    echo "2. Ensure your phone can access the internet"
    echo "3. We'll start Claude Code authentication on this server"
    echo "4. Copy the authentication URL to your phone"
    echo "5. Complete the OAuth login on your phone"
    echo "6. The authentication will sync back to this server"
    echo
    
    read -p "Ready to start phone authentication? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Starting Claude Code authentication..."
        log_info "Look for an authentication URL to copy to your phone"
        echo
        echo -e "${YELLOW}When Claude Code shows an authentication URL:${NC}"
        echo -e "${YELLOW}1. Copy the URL${NC}"
        echo -e "${YELLOW}2. Open it on your phone's browser${NC}"
        echo -e "${YELLOW}3. Log in with your Claude Pro/Max account${NC}"
        echo -e "${YELLOW}4. Return here after completing authentication${NC}"
        echo
        
        # Start Claude Code - this should show the auth URL
        claude || log_warning "Authentication may need to be completed manually"
    else
        log_info "You can authenticate later by running: claude"
        log_info "Then copy the authentication URL to your phone"
    fi
}

# Setup text browser authentication  
setup_text_browser_auth() {
    log_info "Setting up Pro/Max subscription authentication via text browser..."
    
    # Check for available text browsers
    local available_browsers=()
    local browsers=("elinks" "w3m" "lynx" "links")
    
    for browser in "${browsers[@]}"; do
        if command -v "$browser" &>/dev/null; then
            available_browsers+=("$browser")
        fi
    done
    
    if [[ ${#available_browsers[@]} -eq 0 ]]; then
        log_error "No text browsers found (lynx, elinks, w3m, links)"
        log_info "Install one with: sudo pacman -S elinks lynx w3m links"
        log_info "Or choose a different authentication method"
        return 1
    fi
    
    echo
    echo -e "${CYAN}📖 Available text browsers: ${available_browsers[*]}${NC}"
    echo
    echo -e "${YELLOW}Text Browser Authentication Steps:${NC}"
    echo "1. We'll start Claude Code authentication"
    echo "2. Copy the authentication URL when shown"
    echo "3. Open the URL in your text browser"
    echo "4. Navigate through the OAuth flow"
    echo "5. Complete login with your Claude Pro/Max account"
    echo
    echo -e "${YELLOW}Recommended browser: elinks (most user-friendly for OAuth)${NC}"
    echo
    
    read -p "Ready to start text browser authentication? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Starting Claude Code authentication..."
        echo
        echo -e "${YELLOW}When Claude Code shows an authentication URL:${NC}"
        echo -e "${YELLOW}1. Copy the URL${NC}"
        echo -e "${YELLOW}2. Run: ${available_browsers[0]} 'URL_HERE'${NC}"
        echo -e "${YELLOW}3. Navigate through the OAuth flow${NC}"
        echo -e "${YELLOW}4. Return here after completing authentication${NC}"
        echo
        
        # Start Claude Code - this should show the auth URL
        claude || log_warning "Authentication may need to be completed manually"
    else
        log_info "You can authenticate later by running: claude"
        log_info "Then use: ${available_browsers[0]} 'AUTH_URL'"
    fi
}

# Setup X11 forwarding authentication
setup_x11_forwarding_auth() {
    log_info "Setting up Pro/Max subscription authentication via SSH X11 forwarding..."
    echo
    echo -e "${CYAN}🖥️  SSH X11 Forwarding Authentication:${NC}"
    echo
    echo -e "${YELLOW}Requirements:${NC}"
    echo "• SSH client with X11 forwarding enabled (ssh -X)"
    echo "• X11 server running on your local machine"
    echo "• DISPLAY environment variable set"
    echo
    echo -e "${YELLOW}Current environment:${NC}"
    echo "• DISPLAY: ${DISPLAY:-'Not set'}"
    echo "• SSH_CLIENT: ${SSH_CLIENT:-'Not set'}"
    echo
    
    if [[ -z "${DISPLAY:-}" ]]; then
        log_warning "DISPLAY environment variable is not set"
        log_info "You may need to reconnect with: ssh -X user@server"
        log_info "Or set DISPLAY manually if X11 forwarding is working"
    fi
    
    read -p "Do you want to try X11 forwarding authentication? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Starting Claude Code authentication with X11 forwarding..."
        log_info "This should open a browser window on your local machine"
        
        # Test X11 forwarding first
        if command -v xdpyinfo &>/dev/null; then
            if xdpyinfo >/dev/null 2>&1; then
                log_success "X11 forwarding appears to be working"
            else
                log_warning "X11 forwarding may not be working properly"
            fi
        fi
        
        # Start Claude Code
        claude || log_warning "Authentication may need to be completed manually"
    else
        log_info "You can authenticate later by running: claude"
        log_info "Make sure to connect with: ssh -X user@server"
    fi
}

# Setup API key authentication
setup_api_key_auth() {
    # Check for API key in environment first
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_info "Found API key in environment variable"
        if claude config set apiKey "$ANTHROPIC_API_KEY"; then
            log_success "API key configured from environment"
        else
            log_error "Failed to set API key from environment"
        fi
    else
        read -p "Have you obtained your API key from console.anthropic.com? (Y/n): " -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_warning "Authentication setup postponed"
            log_info "Get API key from: https://console.anthropic.com/"
            log_info "Then run: claude config set apiKey YOUR_API_KEY"
            return 0
        fi
        
        # Interactive API key setup
        log_info "Starting API key configuration..."
        log_info "You will be prompted to enter your API key securely"
        
        if claude config; then
            log_success "API key configured successfully"
        else
            log_error "Failed to configure API key"
            log_info "You can configure it manually later with: claude config"
            return 1
        fi
    fi
    
    # Test authentication
    log_info "Testing authentication..."
    if timeout 10 echo "test" | claude -p >/dev/null 2>&1; then
        log_success "Authentication test passed"
    else
        log_warning "Authentication test failed or timed out"
        log_info "You may need to verify your API key manually"
        log_info "Test with: echo 'hello' | claude -p"
    fi
}

# Test Claude Code functionality
test_claude_code() {
    log_section "Testing Claude Code Installation"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would test Claude Code installation"
        return 0
    fi
    
    # Basic command test
    if ! command -v claude &>/dev/null; then
        log_error "Claude Code command not found"
        return 1
    fi
    
    log_info "Testing Claude Code basic functionality..."
    
    # Test version command
    local version_output
    if version_output=$(claude --version 2>/dev/null); then
        log_success "Version command works: $version_output"
    else
        log_warning "Version command failed"
    fi
    
    # Test help command
    if claude --help >/dev/null 2>&1; then
        log_success "Help command works"
    else
        log_warning "Help command failed"
    fi
    
    # Test configuration
    if claude config list >/dev/null 2>&1; then
        log_success "Configuration access works"
    else
        log_warning "Configuration access failed"
    fi
    
    # Simple API test (if authenticated)
    if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
        read -p "Test Claude Code with a simple API call? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Testing with simple prompt..."
            
            local test_prompt="Say 'Hello from Claude Code!' and nothing else."
            local response
            
            if response=$(timeout 15 echo "$test_prompt" | claude -p 2>/dev/null); then
                if [[ -n "$response" ]]; then
                    log_success "Claude Code API test passed!"
                    log_info "Response: $response"
                else
                    log_warning "Claude Code API test returned empty response"
                fi
            else
                log_warning "Claude Code API test failed or timed out"
                log_info "This may be due to authentication issues or network problems"
            fi
        fi
    fi
}

# Create Claude Code utilities
create_claude_utilities() {
    if [[ "$SKIP_UTILITIES" == "true" ]]; then
        log_info "Skipping Claude Code utilities creation"
        return 0
    fi
    
    log_section "Creating Claude Code Utilities"
    
    local bin_dir="$HOME/.local/bin"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would create Claude Code utilities"
        return 0
    fi
    
    mkdir -p "$bin_dir"
    
    # Create quick commit message generator
    local commit_script="$bin_dir/claude-commit"
    cat > "$commit_script" << 'EOF'
#!/bin/bash
# Claude Code Commit Message Generator

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

show_usage() {
    cat << 'USAGE'
Usage: claude-commit [OPTIONS]

Generate intelligent commit messages using Claude Code.

OPTIONS:
    -h, --help          Show this help message
    -p, --preview       Preview message without committing
    -m, --message MSG   Use custom message with Claude enhancement
    -f, --force         Skip confirmation prompts

EXAMPLES:
    claude-commit                       # Generate and commit
    claude-commit --preview             # Generate but don't commit
    claude-commit -m "fix: bug"         # Enhance custom message

USAGE
}

# Parse arguments
PREVIEW_ONLY=false
CUSTOM_MESSAGE=""
FORCE_COMMIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -p|--preview)
            PREVIEW_ONLY=true
            shift
            ;;
        -m|--message)
            if [[ -n "${2:-}" ]]; then
                CUSTOM_MESSAGE="$2"
                shift 2
            else
                echo -e "${RED}Error: --message requires a value${NC}"
                exit 1
            fi
            ;;
        -f|--force)
            FORCE_COMMIT=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Check if in git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check for staged changes
if ! git diff --cached --quiet; then
    echo -e "${BLUE}Staged changes detected${NC}"
else
    echo -e "${YELLOW}No staged changes. Staging all changes...${NC}"
    git add -A
    if ! git diff --cached --quiet; then
        echo -e "${GREEN}Changes staged successfully${NC}"
    else
        echo -e "${RED}No changes to commit${NC}"
        exit 1
    fi
fi

# Generate commit message
echo -e "${BLUE}Analyzing changes with Claude Code...${NC}"

if [[ -n "$CUSTOM_MESSAGE" ]]; then
    prompt="Enhance this commit message to follow conventional commit format: '$CUSTOM_MESSAGE'"
else
    files_changed=$(git diff --cached --name-only | head -10)
    diff_stat=$(git diff --cached --stat)
    
    prompt="Generate a concise git commit message for these changes:

Files: $files_changed

Changes:
$diff_stat

Use conventional commit format (type: description). Be specific and concise."
fi

# Get commit message from Claude
if ! command -v claude >/dev/null 2>&1; then
    echo -e "${RED}Error: Claude Code not found${NC}"
    echo "Install with: npm install -g @anthropic/claude-code"
    exit 1
fi

commit_message=$(echo "$prompt" | claude -p 2>/dev/null | head -1 | sed 's/^["'"'"'`]*//; s/["'"'"'`]*$//')

if [[ -z "$commit_message" ]]; then
    echo -e "${RED}Failed to generate commit message${NC}"
    exit 1
fi

echo -e "${GREEN}Generated commit message:${NC}"
echo "  $commit_message"

if [[ "$PREVIEW_ONLY" == "true" ]]; then
    echo -e "${BLUE}Preview mode - not committing${NC}"
    exit 0
fi

# Confirm and commit
if [[ "$FORCE_COMMIT" != "true" ]]; then
    echo
    read -p "Use this commit message? (Y/n): " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Commit cancelled${NC}"
        exit 0
    fi
fi

if git commit -m "$commit_message"; then
    echo -e "${GREEN}✓ Committed successfully${NC}"
else
    echo -e "${RED}✗ Commit failed${NC}"
    exit 1
fi
EOF
    
    chmod +x "$commit_script"
    log_success "Claude commit utility created: $commit_script"
    
    # Create quick chat script
    local chat_script="$bin_dir/claude-chat"
    cat > "$chat_script" << 'EOF'
#!/bin/bash
# Quick Claude Code Chat

set -euo pipefail

show_usage() {
    echo "Usage: claude-chat [PROMPT]"
    echo ""
    echo "Quick chat with Claude Code."
    echo ""
    echo "Examples:"
    echo "  claude-chat 'Explain Git rebase'"
    echo "  claude-chat                     # Interactive mode"
}

case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
esac

if ! command -v claude >/dev/null 2>&1; then
    echo "Error: Claude Code not found"
    echo "Install with: npm install -g @anthropic/claude-code"
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Starting interactive Claude Code session..."
    echo "Type your questions or 'exit' to quit."
    exec claude
else
    echo "$*" | claude -p
fi
EOF
    
    chmod +x "$chat_script"
    log_success "Claude chat utility created: $chat_script"
    
    # Create project analyzer
    local analyze_script="$bin_dir/claude-analyze"
    cat > "$analyze_script" << 'EOF'
#!/bin/bash
# Claude Code Project Analyzer

set -euo pipefail

show_usage() {
    cat << 'USAGE'
Usage: claude-analyze [TYPE]

Analyze current project with Claude Code.

TYPES:
    code        Analyze code quality and structure
    security    Security vulnerability analysis
    docs        Documentation review
    performance Performance optimization suggestions

Examples:
    claude-analyze code
    claude-analyze security

USAGE
}

case "${1:-code}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    code)
        prompt="Analyze this codebase structure and provide improvement suggestions:"
        ;;
    security)
        prompt="Perform a security analysis of this codebase and identify potential vulnerabilities:"
        ;;
    docs)
        prompt="Review the documentation in this project and suggest improvements:"
        ;;
    performance)
        prompt="Analyze this code for performance optimization opportunities:"
        ;;
    *)
        echo "Unknown analysis type: $1"
        show_usage
        exit 1
        ;;
esac

if ! command -v claude >/dev/null 2>&1; then
    echo "Error: Claude Code not found"
    exit 1
fi

# Get project overview
project_files=$(find . -type f -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.fish" -o -name "*.md" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -20)
project_structure=$(tree -L 3 2>/dev/null || ls -la)

full_prompt="$prompt

Project structure:
$project_structure

Key files:
$project_files

Please provide specific, actionable recommendations."

echo "Analyzing project with Claude Code..."
echo "$full_prompt" | claude -p
EOF
    
    chmod +x "$analyze_script"
    log_success "Claude project analyzer created: $analyze_script"
}

# Set up Claude Code configuration
setup_claude_config() {
    log_section "Setting up Claude Code Configuration"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would set up Claude Code configuration"
        return 0
    fi
    
    # Create config directory
    local config_dir="$HOME/.config/claude-code"
    mkdir -p "$config_dir"
    
    # Create default configuration file
    local config_file="$config_dir/config.json"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
{
  "theme": "dark",
  "autoSave": true,
  "defaultModel": "claude-3-sonnet-20241022",
  "timeout": 30000,
  "maxTokens": 4096,
  "temperature": 0.7,
  "enableLogging": true,
  "logLevel": "info"
}
EOF
        log_success "Created default Claude Code configuration"
    else
        log_info "Claude Code configuration already exists"
    fi
    
    # Set up environment variables
    local env_file="$HOME/.profile"
    if ! grep -q "CLAUDE_CODE_CONFIG" "$env_file" 2>/dev/null; then
        echo "" >> "$env_file"
        echo "# Claude Code configuration" >> "$env_file"
        echo "export CLAUDE_CODE_CONFIG=\"$config_dir/config.json\"" >> "$env_file"
        log_success "Added Claude Code environment variables to .profile"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Install and configure Claude Code CLI for AI-powered development.

OPTIONS:
    -h, --help              Show this help message
    -n, --dry-run           Show what would be done without making changes
    -y, --yes               Skip confirmation prompts
    -f, --force             Force reinstallation even if already installed
    --skip-auth             Skip authentication setup
    --skip-utilities        Skip creating utility scripts
    --log-dir DIR           Custom log directory (default: ~/dotfiles/logs)
    --dotfiles-dir DIR      Custom dotfiles directory (default: auto-detect)

DESCRIPTION:
    This script installs Claude Code CLI and sets it up for seamless integration
    with your development workflow.

FEATURES:
    • Claude Code CLI installation via npm
    • Authentication setup with Anthropic API
    • Utility script creation (claude-commit, claude-chat, claude-analyze)
    • Configuration file setup
    • Integration with existing dotfiles system

REQUIREMENTS:
    • Node.js 18+ and npm
    • Internet connection
    • Anthropic API key (obtained during setup)
    • At least 2GB RAM recommended

UTILITIES CREATED:
    • claude-commit         - AI-powered commit message generation
    • claude-chat           - Quick Claude conversations
    • claude-analyze        - Project analysis and recommendations

EXAMPLES:
    $SCRIPT_NAME                    # Full Claude Code setup
    $SCRIPT_NAME --skip-auth        # Install without authentication
    $SCRIPT_NAME -n                 # Dry run to see what would be done
    $SCRIPT_NAME -f                 # Force reinstallation

AUTHENTICATION:
    Claude Code supports two authentication methods:

    METHOD 1: Pro/Max Subscription (Recommended)
    • Have an active Claude Pro (\$20/month) or Max (\$200/month) subscription
    • Run 'claude' and select subscription login
    • Complete OAuth browser login with your Claude account
    • No API key needed - uses your subscription

    METHOD 2: API Key (Console/PAYG) 
    • Visit https://console.anthropic.com/
    • Create account and generate API key
    • Pay per usage (more cost-effective for light use)
    • Configure with API key

    AUTOMATION OPTIONS:
    • Interactive setup (default) - choose authentication method
    • Environment variable - set ANTHROPIC_API_KEY for API key method
    • Manual setup later - skip with --skip-auth, configure manually

    HEADLESS/SSH ENVIRONMENTS:
    • OAuth authentication requires browser access and may fail in SSH sessions
    • API key authentication is recommended for headless environments
    • Alternative OAuth methods: phone/mobile browser, text browsers, X11 forwarding
    • Set ANTHROPIC_API_KEY environment variable for fully automated setup
    • The script automatically detects SSH sessions and provides multiple options

POST-INSTALLATION:
    After installation, you can use:
    • 'claude' for interactive sessions
    • 'claude-commit' for smart git commits
    • 'claude-chat "question"' for quick queries
    • 'claude-analyze code' for project analysis

HEADLESS/SSH USAGE EXAMPLES:
    # Setup with environment variable (recommended for automation)
    export ANTHROPIC_API_KEY="sk-ant-your-key-here"
    $SCRIPT_NAME -y

    # Manual API key setup after installation
    $SCRIPT_NAME --skip-auth
    claude config set apiKey "sk-ant-your-key-here"

    # OAuth via phone/mobile device
    $SCRIPT_NAME  # Choose option 2 in headless mode
    # Copy auth URL to phone browser

    # OAuth via text browser (if available)
    sudo pacman -S elinks
    $SCRIPT_NAME  # Choose option 3 in headless mode

    # Test headless mode
    echo "Hello Claude" | claude -p

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            -f|--force)
                FORCE_REINSTALL=true
                shift
                ;;
            --skip-auth)
                SKIP_AUTHENTICATION=true
                shift
                ;;
            --skip-utilities)
                SKIP_UTILITIES=true
                shift
                ;;
            --log-dir)
                if [[ -n "${2:-}" ]]; then
                    LOG_DIR="$2"
                    LOG_FILE="${LOG_DIR}/claude-code-setup_$(date +%Y%m%d_%H%M%S).log"
                    shift 2
                else
                    log_error "--log-dir requires a directory path"
                    exit 1
                fi
                ;;
            --dotfiles-dir)
                if [[ -n "${2:-}" ]]; then
                    DOTFILES_DIR="$2"
                    shift 2
                else
                    log_error "--dotfiles-dir requires a directory path"
                    exit 1
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    init_logging
    
    echo "=== Claude Code CLI Setup ==="
    echo "Log file: $LOG_FILE"
    echo "Dotfiles directory: $DOTFILES_DIR"
    echo
    
    check_prerequisites
    install_claude_code
    configure_authentication
    setup_claude_config
    create_claude_utilities
    test_claude_code
    
    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed - no changes were made"
    else
        log_success "Claude Code setup completed!"
        log_info "Use 'claude' for interactive AI sessions"
        log_info "Use 'claude-commit' for smart git commits"
        log_info "Use 'claude-chat' for quick conversations"
        log_info "Use 'claude-analyze' for project analysis"
        
        if [[ "$SKIP_AUTHENTICATION" == "true" ]]; then
            echo
            log_warning "Authentication was skipped!"
            log_info "Configure your API key with: claude config"
            log_info "Get your API key from: https://console.anthropic.com/"
        fi
    fi
    
    echo "Log file: $LOG_FILE"
}

# Run main function
main "$@"