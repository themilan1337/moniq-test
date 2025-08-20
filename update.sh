#!/bin/bash

# Moniq CLI Update Script
# curl -sfL https://get.moniq.sh/update.sh | bash

set -e

# Colors
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print header
print_header() {
    printf "\n"
    printf "${CYAN}███╗   ███╗ ██████╗ ███╗   ██╗██╗ ██████╗    ███████╗██╗  ██╗${NC}\n"
    printf "${CYAN}████╗ ████║██╔═══██╗████╗  ██║██║██╔═══██╗   ██╔════╝██║  ██║${NC}\n"
    printf "${CYAN}██╔████╔██║██║   ██║██╔██╗ ██║██║██║   ██║   ███████╗███████║${NC}\n"
    printf "${CYAN}██║╚██╔╝██║██║   ██║██║╚██╗██║██║██║▄▄ ██║   ╚════██║██╔══██║${NC}\n"
    printf "${CYAN}██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║╚██████╔╝██╗███████║██║  ██║${NC}\n"
    printf "${CYAN}╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚══▀▀═╝ ╚═╝╚══════╝╚═╝ ╚═╝${NC}\n"
    printf "\n"
    printf "                    ${WHITE}Server Monitor${NC}\n"
    printf "\n"
}

# Print section
print_section() {
    local title="$1"
    local total_width=70
    local prefix="+- "
    local suffix="-+"
    local title_len=${#title}
    local dash_count=$((total_width - ${#prefix} - ${#suffix} - title_len))
    if [ $dash_count -lt 0 ]; then dash_count=0; fi
    printf "${CYAN}${prefix}${WHITE}%s${CYAN}%s${suffix}${NC}\n" "$title" "$(printf '%*s' $dash_count | sed 's/ /-/g')"
}

# Print section end
print_section_end() {
    local total_width=70
    printf "${CYAN}+%s+${NC}\n" "$(printf '%*s' $((total_width-2)) | sed 's/ /-/g')"
}

# Print status
print_status() {
    local type="$1"
    local message="$2"
    case $type in
        "success") printf "  ${GREEN}✓ $message${NC}\n" ;;
        "info") printf "  ${BLUE}ℹ $message${NC}\n" ;;
        "warning") printf "  ${YELLOW}⚠ $message${NC}\n" ;;
        "error") printf "  ${RED}✗ $message${NC}\n" ;;
    esac
}

# Check if moniq is installed
check_installation() {
    if ! command -v moniq &> /dev/null; then
        print_status "error" "Moniq CLI is not installed"
        print_status "info" "Please install first: curl -sfL https://get.moniq.sh/install.sh | bash"
        exit 1
    fi
}

# Check for updates via API
check_for_updates() {
    print_status "info" "Checking for updates..."
    
    # Get current version from moniq binary
    CURRENT_VERSION=$(moniq --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//' || echo "0.0.0")
    
    # Check API for latest version
    API_RESPONSE=$(curl -s "https://api.moniq.sh/api/versions/check" 2>/dev/null || echo "{}")
    LATEST_VERSION=$(echo "$API_RESPONSE" | grep -o '"latest_version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "0.0.0")
    
    if [ "$LATEST_VERSION" = "0.0.0" ] || [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
        print_status "info" "No updates available (current: $CURRENT_VERSION)"
        print_section_end
        return 1
    fi
    
    print_status "success" "Update available! Latest version: $LATEST_VERSION"
    return 0
}

# Function to kill duplicate processes
kill_duplicate_processes() {
    print_status "info" "Checking for duplicate moniq processes..."
    
    # Find all moniq daemon processes
    local pids=$(pgrep -f "moniq daemon" 2>/dev/null)
    if [ -n "$pids" ]; then
        local pid_count=$(echo "$pids" | wc -l)
        if [ "$pid_count" -gt 1 ]; then
            print_status "warning" "Found $pid_count duplicate moniq daemon processes"
            
            # Keep the first process, kill the rest
            local first_pid=$(echo "$pids" | head -n1)
            echo "$pids" | tail -n +2 | while read pid; do
                if [ "$pid" != "$first_pid" ]; then
                    print_status "info" "Killing duplicate process PID: $pid"
                    kill "$pid" 2>/dev/null
                fi
            done
            
            print_status "success" "Duplicate processes killed, keeping PID: $first_pid"
        else
            print_status "info" "Only one moniq daemon process running (PID: $(echo $pids))"
        fi
    else
        print_status "info" "No moniq daemon processes found"
    fi
}

# Stop moniq service if running
stop_service() {
    # Kill any duplicate processes first
    kill_duplicate_processes
    
    if pgrep -f "moniq daemon" > /dev/null; then
        print_status "info" "Stopping monitoring service..."
        pkill -f "moniq daemon" || true
        sleep 2
    fi
}

# Determine OS and architecture
get_system_info() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Map architecture names
    case $ARCH in
        "x86_64") ARCH="amd64" ;;
        "aarch64") ARCH="arm64" ;;
        "arm64") ARCH="arm64" ;;
    esac
    
    BINARY_NAME="moniq-$OS-$ARCH"
    print_status "info" "System: $OS-$ARCH"
}

# Download and install new version
download_and_install() {
    print_status "info" "Downloading latest version..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Download binary
    if curl -sfL "https://get.moniq.sh/$BINARY_NAME" -o "$TEMP_DIR/moniq"; then
        chmod +x "$TEMP_DIR/moniq"
        print_status "success" "Download completed"
    else
        print_status "error" "Download failed"
        exit 1
    fi
    
    # Find current moniq location
    CURRENT_MONIQ=$(which moniq)
    
    # Backup old version
    if [ -f "$CURRENT_MONIQ" ]; then
        cp "$CURRENT_MONIQ" "$CURRENT_MONIQ.backup"
        print_status "info" "Backup created: $CURRENT_MONIQ.backup"
    fi
    
    # Install new version
    if [ -w "$(dirname "$CURRENT_MONIQ")" ]; then
        # Direct replacement
        mv "$TEMP_DIR/moniq" "$CURRENT_MONIQ"
    else
        # Use sudo if needed
        sudo mv "$TEMP_DIR/moniq" "$CURRENT_MONIQ"
    fi
    
    print_status "success" "Installation completed"
}

# Test new installation
test_installation() {
    print_status "info" "Testing new installation..."
    if moniq --help > /dev/null 2>&1; then
        print_status "success" "New version works correctly"
    else
        print_status "error" "New version test failed"
        print_status "info" "Restoring backup..."
        if [ -f "$CURRENT_MONIQ.backup" ]; then
            if [ -w "$(dirname "$CURRENT_MONIQ")" ]; then
                mv "$CURRENT_MONIQ.backup" "$CURRENT_MONIQ"
            else
                sudo mv "$CURRENT_MONIQ.backup" "$CURRENT_MONIQ"
            fi
        fi
        exit 1
    fi
}

# Start service if it was running
start_service() {
    print_status "info" "Starting monitoring service..."
    
    # Kill any duplicate processes before starting
    kill_duplicate_processes
    
    if moniq start > /dev/null 2>&1; then
        print_status "success" "Monitoring service started"
    else
        print_status "warning" "Could not start monitoring service automatically"
        print_status "info" "Run 'moniq start' to start monitoring manually"
    fi
}

# Send update statistics
send_update_stats() {
    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    case $arch in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
        "arm64") arch="arm64" ;;
    esac

    # Send stats silently (don't interrupt update)
    curl -s -X POST "https://api.moniq.sh/api/downloads/install" \
        -H "Content-Type: application/json" \
        -H "User-Agent: Moniq-CLI/1.0.0" \
        -H "X-Platform: $platform" \
        -H "X-Version: 1.0.0" \
        -d "{\"platform\":\"$platform\",\"architecture\":\"$arch\",\"type\":\"update\",\"timestamp\":\"$(date +%s)\"}" \
        >/dev/null 2>&1 || true
}

# Main function
main() {
    print_header
    
    print_section "Updating Moniq CLI"
    
    check_installation
    check_for_updates
    
    # If no updates available, exit after closing section
    if [ $? -eq 1 ]; then
        print_section_end
        exit 0
    fi
    
    stop_service
    get_system_info
    download_and_install
    test_installation
    start_service
    
    print_section_end
    
    print_section "Update Complete"
    print_status "success" "Moniq CLI updated successfully"
    print_status "info" "Run 'moniq status' to check your system"
    print_status "info" "Run 'moniq --help' to see all commands"
    
    # Send update statistics
    send_update_stats
    
    print_section_end
}

main 