#!/bin/sh

# Moniq CLI Installation Script
# curl -sfL https://get.moniq.sh | BOT_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz" GROUP_ID="123456789" sh -
# curl -sfL https://get.moniq.sh | BOT_ID="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz" GROUP_ID="123456789" sh -  # Legacy support

set -e

# Set locale for Unicode support
export LC_ALL=C.utf8
export LANG=C.utf8

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
    printf "${CYAN}╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚══▀▀═╝ ╚═╝╚══════╝╚═╝  ╚═╝${NC}\n"
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

# Log message to /tmp/moniq.log
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $level: $message" >> /tmp/moniq.log
}

create_directories() {
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.moniq"
}

download_binary() {
    CLI_DIR="$HOME/.local/bin"
    
    # Try to use Go binary for current OS/arch
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    # Map architecture names to binary names
    case $ARCH in
        "x86_64") ARCH="amd64" ;;
        "aarch64") ARCH="arm64" ;;
        "arm64") ARCH="arm64" ;;
    esac
    
    BINARY_NAME="moniq-$OS-$ARCH"
    
    # Log download start
    log_message "INFO" "Download started - Binary: $BINARY_NAME, URL: https://get.moniq.sh/$BINARY_NAME"
    
    # Download binary from server
    print_status "info" "Downloading Moniq CLI..."
    if curl -sfL "https://get.moniq.sh/$BINARY_NAME" -o "$CLI_DIR/moniq"; then
        chmod +x "$CLI_DIR/moniq"
        print_status "success" "Download completed"
        log_message "INFO" "Download completed successfully - Binary: $BINARY_NAME"
    else
        print_status "error" "Download failed"
        log_message "ERROR" "Download failed - Binary: $BINARY_NAME"
        exit 1
    fi
}

add_to_path() {
    CLI_DIR="$HOME/.local/bin"
    
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
    
    if ! grep -q "$CLI_DIR" "$SHELL_RC" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    fi
    
    # Create symlink in /usr/local/bin for immediate access
    if [ -w /usr/local/bin ]; then
        ln -sf "$CLI_DIR/moniq" /usr/local/bin/moniq
    else
        # Fallback: create alias in current session
        alias moniq="$CLI_DIR/moniq"
    fi
}

auto_configure() {
    	# Support both BOT_TOKEN and BOT_ID for backward compatibility
	if [ -n "$BOT_TOKEN" ] && [ -n "$GROUP_ID" ]; then
		BOT_TOKEN_VALUE="$BOT_TOKEN"
		GROUP_ID_VALUE="$GROUP_ID"
	elif [ -n "$BOT_ID" ] && [ -n "$GROUP_ID" ]; then
		BOT_TOKEN_VALUE="$BOT_ID"
		GROUP_ID_VALUE="$GROUP_ID"
	fi
	
	# Create config directory
	mkdir -p "$HOME/.moniq"
	
	# Start building config content
	CONFIG_CONTENT=""
	
	# Add Telegram configuration if provided
	if [ -n "$BOT_TOKEN_VALUE" ] && [ -n "$GROUP_ID_VALUE" ]; then
		CONFIG_CONTENT="${CONFIG_CONTENT}telegram_token: $BOT_TOKEN_VALUE
chat_id: $GROUP_ID_VALUE
"
		print_status "success" "Telegram bot configured"
	fi
	
	# Add auth token if provided
	if [ -n "$AUTH_TOKEN" ]; then
		CONFIG_CONTENT="${CONFIG_CONTENT}auth_token: $AUTH_TOKEN
"
		print_status "success" "Authentication token configured"
	fi
	
	# Add default thresholds
	CONFIG_CONTENT="${CONFIG_CONTENT}cpu_threshold: 80.0
mem_threshold: 80.0
disk_threshold: 90.0
"
	
	# Write config file
	echo "$CONFIG_CONTENT" > "$HOME/.moniq/config.yaml"
}

test_installation() {
    CLI_DIR="$HOME/.local/bin"
    MONIQ_BINARY="$CLI_DIR/moniq"
    
    # Log test start
    log_message "INFO" "Testing installation - Binary: $MONIQ_BINARY"
    
    # Check if binary exists
    if [ ! -f "$MONIQ_BINARY" ]; then
        log_message "ERROR" "Binary not found: $MONIQ_BINARY"
        print_status "error" "Binary not found: $MONIQ_BINARY"
        exit 1
    fi
    
    # Check binary permissions
    if [ ! -x "$MONIQ_BINARY" ]; then
        log_message "ERROR" "Binary not executable: $MONIQ_BINARY"
        print_status "error" "Binary not executable: $MONIQ_BINARY"
        exit 1
    fi
    
    # Log binary info
    log_message "INFO" "Binary exists and is executable"
    log_message "INFO" "Binary size: $(ls -lh "$MONIQ_BINARY" | awk '{print $5}')"
    log_message "INFO" "Binary permissions: $(ls -la "$MONIQ_BINARY" | awk '{print $1}')"
    
    # Test the binary with more detailed logging
    log_message "INFO" "Testing binary with --help flag..."
    if "$MONIQ_BINARY" --help >/dev/null 2>&1; then
        log_message "SUCCESS" "Binary test passed - --help flag works"
        print_status "success" "Installation test passed"
    else
        local exit_code=$?
        log_message "ERROR" "Binary test failed with exit code: $exit_code"
        log_message "ERROR" "Binary output: $("$MONIQ_BINARY" --help 2>&1)"
        print_status "error" "Installation failed - binary test failed"
        exit 1
    fi
}

auto_start() {
	CLI_DIR="$HOME/.local/bin"
	
	# Create autostart service (without manual start to avoid duplicate Telegram messages)
	if [ "$OS" = "linux" ]; then
		create_systemd_service
	elif [ "$OS" = "darwin" ]; then
		create_launchd_service
	else
		# Fallback for other systems
		create_crontab_service
	fi
	
	print_status "success" "Autostart service configured"
	print_status "info" "Monitoring will start automatically on boot"
}

create_systemd_service() {
	print_status "info" "Creating systemd service for autostart..."
	
	# Check if systemd is available
	if ! command -v systemctl >/dev/null 2>&1; then
		print_status "warning" "systemctl not found, skipping systemd service creation"
		return
	fi
	
	# Create systemd user directory
	mkdir -p "$HOME/.config/systemd/user"
	
	# Create wrapper script for duplicate protection
	local wrapper_script="$HOME/.moniq/start_moniq.sh"
	cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# Wrapper script to start moniq daemon safely
CLI_DIR="$HOME/.local/bin"

# Kill any duplicate processes first
pids=$(pgrep -f "moniq daemon" 2>/dev/null)
if [ -n "$pids" ]; then
    pid_count=$(echo "$pids" | wc -l)
    if [ "$pid_count" -gt 1 ]; then
        # Keep the first process, kill the rest
        first_pid=$(echo "$pids" | head -n1)
        echo "$pids" | tail -n +2 | while read pid; do
            if [ "$pid" != "$first_pid" ]; then
                kill "$pid" 2>/dev/null
            fi
        done
    fi
fi

# Start the daemon
exec "$CLI_DIR/moniq" daemon
EOF
	chmod +x "$wrapper_script"
	
	# Create service file
	cat > "$HOME/.config/systemd/user/moniq.service" << EOF
[Unit]
Description=Moniq System Monitor
After=network.target

[Service]
Type=simple
ExecStart=$wrapper_script
Restart=always
RestartSec=10
Environment=PATH=$CLI_DIR:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
EOF

	# Try to enable the service (without starting)
	if systemctl --user daemon-reload 2>/dev/null; then
		if systemctl --user enable moniq.service 2>/dev/null; then
			print_status "success" "Systemd service created and enabled"
			print_status "info" "Service will start automatically on boot"
			# Start service immediately if enabled successfully
			if systemctl --user start moniq.service 2>/dev/null; then
				print_status "success" "Monitoring service started via systemd"
				log_message "SUCCESS" "Monitoring service started via systemd"
			else
				print_status "warning" "Could not start service via systemd, starting manually..."
				# Kill any duplicate processes before starting manually
				kill_duplicate_processes
				if nohup "$CLI_DIR/moniq" daemon > /dev/null 2>&1 & then
					print_status "success" "Monitoring service started manually"
					log_message "SUCCESS" "Monitoring service started manually after systemd failure"
				fi
			fi
		else
			print_status "warning" "Could not enable systemd service, but service file created"
			print_status "info" "You can enable it manually with: systemctl --user enable moniq.service"
					# Start service manually if enable failed
		print_status "info" "Starting monitoring service manually..."
		# Kill any duplicate processes before starting manually
		kill_duplicate_processes
		if nohup "$CLI_DIR/moniq" daemon > /dev/null 2>&1 & then
			print_status "success" "Monitoring service started manually"
			log_message "SUCCESS" "Monitoring service started manually after launchd failure"
		fi
		fi
	else
		print_status "warning" "Could not reload systemd daemon, but service file created"
		print_status "info" "You can reload manually with: systemctl --user daemon-reload"
		# Fallback: start service manually if systemd fails
		print_status "info" "Starting monitoring service manually..."
		if nohup "$CLI_DIR/moniq" daemon > /dev/null 2>&1 & then
			print_status "success" "Monitoring service started manually"
		else
			print_status "warning" "Could not start monitoring service manually"
			print_status "info" "You can start it manually with: moniq start"
		fi
	fi
}

create_launchd_service() {
	print_status "info" "Creating launchd service for autostart..."
	
	# Create wrapper script for duplicate protection
	local wrapper_script="$HOME/.moniq/start_moniq.sh"
	cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# Wrapper script to start moniq daemon safely
CLI_DIR="$HOME/.local/bin"

# Kill any duplicate processes first
pids=$(pgrep -f "moniq daemon" 2>/dev/null)
if [ -n "$pids" ]; then
    pid_count=$(echo "$pids" | wc -l)
    if [ "$pid_count" -gt 1 ]; then
        # Keep the first process, kill the rest
        first_pid=$(echo "$pids" | head -n1)
        echo "$pids" | tail -n +2 | while read pid; do
            if [ "$pid" != "$first_pid" ]; then
                kill "$pid" 2>/dev/null
            fi
        done
    fi
fi

# Start the daemon
exec "$CLI_DIR/moniq" daemon
EOF
	chmod +x "$wrapper_script"
	
	# Create launchd plist file
	cat > "$HOME/Library/LaunchAgents/com.moniq.monitor.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.moniq.monitor</string>
	<key>ProgramArguments</key>
	<array>
		<string>$wrapper_script</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/tmp/moniq.log</string>
	<key>StandardErrorPath</key>
	<string>/tmp/moniq.log</string>
</dict>
</plist>
EOF

	# Load the service
	if launchctl load "$HOME/Library/LaunchAgents/com.moniq.monitor.plist" 2>/dev/null; then
		print_status "success" "Launchd service created and enabled"
		print_status "info" "Service will start automatically on boot"
	else
		print_status "warning" "Launchd service created but could not be loaded"
		print_status "info" "You can start it manually with: launchctl load ~/Library/LaunchAgents/com.moniq.monitor.plist"
	fi
}

create_crontab_service() {
	print_status "info" "Creating crontab entry for autostart..."
	
	CLI_DIR="$HOME/.local/bin"
	
	# Add to crontab if not already present
	if ! crontab -l 2>/dev/null | grep -q "moniq daemon"; then
		# Use a wrapper script that kills duplicates before starting
		local wrapper_script="$HOME/.moniq/start_moniq.sh"
		cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# Wrapper script to start moniq daemon safely
CLI_DIR="$HOME/.local/bin"

# Kill any duplicate processes first
pids=$(pgrep -f "moniq daemon" 2>/dev/null)
if [ -n "$pids" ]; then
    pid_count=$(echo "$pids" | wc -l)
    if [ "$pid_count" -gt 1 ]; then
        # Keep the first process, kill the rest
        first_pid=$(echo "$pids" | head -n1)
        echo "$pids" | tail -n +2 | while read pid; do
            if [ "$pid" != "$first_pid" ]; then
                kill "$pid" 2>/dev/null
            fi
        done
    fi
fi

# Start the daemon
exec "$CLI_DIR/moniq" daemon
EOF
		chmod +x "$wrapper_script"
		
		(crontab -l 2>/dev/null; echo "@reboot $wrapper_script > /dev/null 2>&1 &") | crontab -
		print_status "success" "Crontab entry created for autostart with duplicate protection"
		print_status "info" "Service will start automatically on boot with duplicate process protection"
	else
		print_status "info" "Crontab entry already exists"
	fi
}

# Function to kill duplicate processes
kill_duplicate_processes() {
    log_message "INFO" "Checking for duplicate moniq processes..."
    
    # Find all moniq daemon processes
    local pids=$(pgrep -f "moniq daemon" 2>/dev/null)
    if [ -n "$pids" ]; then
        local pid_count=$(echo "$pids" | wc -l)
        if [ "$pid_count" -gt 1 ]; then
            log_message "WARNING" "Found $pid_count duplicate moniq daemon processes"
            
            # Keep the first process, kill the rest
            local first_pid=$(echo "$pids" | head -n1)
            echo "$pids" | tail -n +2 | while read pid; do
                if [ "$pid" != "$first_pid" ]; then
                    log_message "INFO" "Killing duplicate process PID: $pid"
                    kill "$pid" 2>/dev/null
                fi
            done
            
            log_message "SUCCESS" "Duplicate processes killed, keeping PID: $first_pid"
        else
            log_message "INFO" "Only one moniq daemon process running (PID: $(echo $pids))"
        fi
    else
        log_message "INFO" "No moniq daemon processes found"
    fi
}

# Function to start monitoring service safely
auto_start() {
    print_status "info" "Starting monitoring service..."
    
    # Kill any duplicate processes first
    kill_duplicate_processes
    
    # Check if service is already running
    if pgrep -f "moniq daemon" >/dev/null; then
        print_status "warning" "Monitoring service is already running"
        return 0
    fi
    
    # Start the service
    if nohup "$CLI_DIR/moniq" daemon > /dev/null 2>&1 & then
        local start_pid=$!
        print_status "success" "Monitoring service started successfully (PID: $start_pid)"
        log_message "SUCCESS" "Monitoring service started via auto_start (PID: $start_pid)"
        return 0
    else
        print_status "error" "Failed to start monitoring service"
        log_message "ERROR" "Failed to start monitoring service via auto_start"
        return 1
    fi
}

# Function to get CPU cores
get_cpu_cores() {
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS
        sysctl -n hw.ncpu 2>/dev/null || echo "0"
    elif [ "$(uname -s)" = "Linux" ]; then
        # Linux
        nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get total memory in GB
get_total_memory() {
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS
        local memory_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
        echo $((memory_bytes / 1024 / 1024 / 1024))
    elif [ "$(uname -s)" = "Linux" ]; then
        # Linux
        local memory_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
        echo $((memory_kb / 1024 / 1024))
    else
        echo "0"
    fi
}

# Function to get total storage in GB
get_total_storage() {
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS
        df -g / | tail -1 | awk '{print $2}' 2>/dev/null || echo "0"
    elif [ "$(uname -s)" = "Linux" ]; then
        # Linux
        df -BG / | tail -1 | awk '{print $2}' | sed 's/G//' 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Send installation statistics
send_install_stats() {
    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    case $arch in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
        "arm64") arch="arm64" ;;
    esac
    
    # Get server specifications
    local cpu_cores=$(get_cpu_cores)
    local total_memory=$(get_total_memory)
    local total_storage=$(get_total_storage)
    
    # Log server specs for debugging
    log_message "DEBUG" "Server specs - CPU: ${cpu_cores} cores, Memory: ${total_memory} GB, Storage: ${total_storage} GB"
    
    # Подготавливаем данные для отправки
    local data="{\"platform\":\"$platform\",\"architecture\":\"$arch\",\"type\":\"install\",\"timestamp\":\"$(date +%s)\""
    
    # Если есть AUTH_TOKEN, добавляем информацию о сервере
    if [ -n "$AUTH_TOKEN" ]; then
        local hostname=$(hostname)
        if [ -n "$hostname" ]; then
            # Экранируем JSON
            local escaped_token=$(echo "$AUTH_TOKEN" | sed 's/"/\\"/g')
            # Get Moniq version from version.txt
            local moniq_version="0.0.6"  # Default fallback
            if [ -f "version.txt" ]; then
                moniq_version=$(cat version.txt | tr -d '\n\r')
            fi
            
            data="${data},\"user_token\":\"$escaped_token\",\"server_info\":{\"hostname\":\"$hostname\",\"os_type\":\"$platform\",\"moniq_version\":\"$moniq_version\"}"
            
            # Add server specifications
            data="${data},\"cpu_cores\":$cpu_cores,\"total_memory\":$total_memory,\"total_storage\":$total_storage"
        fi
    fi
    
    data="${data}}"
    
    # Log the JSON data being sent for debugging
    log_message "DEBUG" "Sending JSON data: $data"
    
    # Log installation request start
    log_message "INFO" "Installation request started - URL: https://api.moniq.sh/api/downloads/install"
    
    # Send stats and get response
    local response=$(curl -s -X POST "https://api.moniq.sh/api/downloads/install" \
        -H "Content-Type: application/json" \
        -H "User-Agent: Moniq-CLI/1.0.0" \
        -H "X-Platform: $platform" \
        -H "X-Version: 1.0.0" \
        -d "$data" 2>/dev/null || echo '{"success":false}')
    
    # Extract server_token from response if successful (same approach as Go code)
    if [ -n "$response" ]; then
        # Log full response for debugging
        log_message "INFO" "Full response received: $response"
        
        # Check if response contains success field (same as Go: result["success"] == true)
        if echo "$response" | grep -q '"success"'; then
            # Extract server_token from data.server_token (same as Go: data["server_token"])
            local server_token=""
            
            # Method 1: Use jq for proper JSON parsing (same logic as Go)
            if command -v jq >/dev/null 2>&1; then
                server_token=$(echo "$response" | jq -r '.data.server_token // empty' 2>/dev/null)
                if [ -n "$server_token" ]; then
                    log_message "INFO" "server_token extracted with jq: $server_token"
                fi
            fi
            
            # Method 2: Fallback to grep if jq not available
            if [ -z "$server_token" ]; then
                server_token=$(echo "$response" | grep -o '"server_token":"[^"]*"' | cut -d'"' -f4)
                if [ -n "$server_token" ]; then
                    log_message "INFO" "server_token extracted with grep fallback: $server_token"
                fi
            fi
            
            if [ -n "$server_token" ]; then
                # Save server_token to config (same as Go: cfg.ServerToken = serverToken)
                local config_file="$HOME/.moniq/config.yaml"
                if [ -f "$config_file" ]; then
                    # Add server_token to config if not already present
                    if ! grep -q "server_token:" "$config_file"; then
                        echo "server_token: $server_token" >> "$config_file"
                        log_message "INFO" "server_token added to config: $server_token"
                    else
                        # Update existing server_token
                        sed -i.bak "s/server_token:.*/server_token: $server_token/" "$config_file"
                        log_message "INFO" "server_token updated in config: $server_token"
                    fi
                else
                    log_message "ERROR" "Config file not found: $config_file"
                fi
            else
                log_message "WARNING" "server_token not found in response - tried jq and grep methods"
                log_message "WARNING" "Response structure: $(echo "$response" | head -c 200)..."
            fi
        else
            log_message "ERROR" "Installation request failed - no success field in response: $response"
        fi
    else
        log_message "ERROR" "Installation request failed - no response"
    fi
}

main() {
    # Log installation start
    log_message "INFO" "Installation script started"
    
    print_header
    
    print_section "Installing Moniq CLI"
    create_directories
    download_binary
    add_to_path
    auto_configure
    test_installation
    auto_start
    print_section_end
    
    print_section "Installation Complete"
    print_status "success" "Moniq CLI installed successfully"
    print_status "info" "Run 'moniq status' to check your system"
    print_status "info" "Run 'moniq --help' to see all commands"
    
    # Send installation statistics
    send_install_stats
    
    # Final check for duplicate processes after installation
    print_status "info" "Performing final duplicate process check..."
    kill_duplicate_processes
    
    # Log installation completion
    log_message "INFO" "Installation completed successfully"
    
    print_section_end
}

main 