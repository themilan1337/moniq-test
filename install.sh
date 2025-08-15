#!/bin/sh

# Moniq CLI Tool Installer
# curl -sfL https://moniq.sh | BOT_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz" GROUP_ID="123456789" sh -
# curl -sfL https://moniq.sh | BOT_ID="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz" GROUP_ID="123456789" sh -  # Legacy support

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
    printf "${CYAN}╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚══▀▀═╝ ╚═╝╚══════╝╚═╝ ╚═╝${NC}\n"
    printf "\n"
    printf "                    ${WHITE}Professional Edition${NC}\n"
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
    
    # Download binary from server
    print_status "info" "Downloading Moniq CLI..."
    if curl -sfL "https://moniq.sh/$BINARY_NAME" -o "$CLI_DIR/moniq"; then
        chmod +x "$CLI_DIR/moniq"
        print_status "success" "Download completed"
    else
        print_status "error" "Download failed"
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
    # Test the binary directly
    if ! "$CLI_DIR/moniq" --help >/dev/null 2>&1; then
        print_status "error" "Installation failed"
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
	
	# Create service file
	cat > "$HOME/.config/systemd/user/moniq.service" << EOF
[Unit]
Description=Moniq System Monitor
After=network.target

[Service]
Type=simple
ExecStart=$CLI_DIR/moniq daemon
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
			else
				print_status "warning" "Could not start service via systemd, starting manually..."
				if nohup "$CLI_DIR/moniq" daemon > /dev/null 2>&1 & then
					print_status "success" "Monitoring service started manually"
				fi
			fi
		else
			print_status "warning" "Could not enable systemd service, but service file created"
			print_status "info" "You can enable it manually with: systemctl --user enable moniq.service"
			# Start service manually if enable failed
			print_status "info" "Starting monitoring service manually..."
			if nohup "$CLI_DIR/moniq" daemon > /dev/null 2>&1 & then
				print_status "success" "Monitoring service started manually"
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
		<string>$CLI_DIR/moniq</string>
		<string>daemon</string>
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
		(crontab -l 2>/dev/null; echo "@reboot $CLI_DIR/moniq daemon > /dev/null 2>&1 &") | crontab -
		print_status "success" "Crontab entry created for autostart"
		print_status "info" "Service will start automatically on boot"
	else
		print_status "info" "Crontab entry already exists"
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
        fi
    fi
    
    data="${data}}"
    
    # Send stats and get response
    local response=$(curl -s -X POST "https://api.moniq.sh/api/downloads/install" \
        -H "Content-Type: application/json" \
        -H "User-Agent: Moniq-CLI/1.0.0" \
        -H "X-Platform: $platform" \
        -H "X-Version: 1.0.0" \
        -d "$data" 2>/dev/null || echo '{"success":false}')
    
    # Extract server_token from response if successful
    if [ -n "$response" ]; then
        # Check if response contains success: true
        if echo "$response" | grep -q '"success":\s*true'; then
            # Extract server_token from data.server_token
            local server_token=$(echo "$response" | grep -o '"server_token":"[^"]*"' | cut -d'"' -f4)
            if [ -n "$server_token" ]; then
                # Save server_token to config
                local config_file="$HOME/.moniq/config.yaml"
                if [ -f "$config_file" ]; then
                    # Add server_token to config if not already present
                    if ! grep -q "server_token:" "$config_file"; then
                        echo "server_token: $server_token" >> "$config_file"
                    else
                        # Update existing server_token
                        sed -i.bak "s/server_token:.*/server_token: $server_token/" "$config_file"
                    fi
                fi
            fi
        fi
    fi
}

main() {
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
    
    print_section_end
}

main 