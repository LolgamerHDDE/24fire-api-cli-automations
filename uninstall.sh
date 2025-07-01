#!/bin/bash

# 24Fire Automation System Uninstaller
echo "🗑️  24Fire Automation System Uninstaller"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/debian_version ]; then
        OS="debian"
        print_status "Detected Debian/Ubuntu system"
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
        print_status "Detected RedHat/CentOS/Fedora system"
    else
        OS="linux"
        print_status "Detected generic Linux system"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    print_status "Detected macOS system"
else
    print_warning "Unknown OS type: $OSTYPE"
    OS="unknown"
fi

# Set application directory based on OS
APP_DIR="/opt/24fire-automation"
if [ "$OS" = "macos" ]; then
    APP_DIR="$HOME/24fire-automation"
fi

SERVICE_NAME="24fire-automation"
CLI_SCRIPT="/usr/local/bin/24fire-automation"

# Confirmation prompt
echo ""
print_warning "This will completely remove the 24Fire Automation System including:"
echo "  - Application files in $APP_DIR"
echo "  - System service (if installed)"
echo "  - CLI management script"
echo "  - Log files"
echo "  - Configuration files (including your API keys)"
echo ""

if [ -t 0 ]; then
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uninstallation cancelled."
        exit 0
    fi
else
    print_warning "Running in non-interactive mode. Proceeding with uninstallation..."
fi

echo ""
print_status "Starting uninstallation process..."

# Stop and disable service
if [ "$OS" != "macos" ]; then
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        print_status "Stopping $SERVICE_NAME service..."
        sudo systemctl stop $SERVICE_NAME
        print_success "Service stopped"
    fi
    
    if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
        print_status "Disabling $SERVICE_NAME service..."
        sudo systemctl disable $SERVICE_NAME
        print_success "Service disabled"
    fi
    
    # Remove systemd service file
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        print_status "Removing systemd service file..."
        sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        sudo systemctl daemon-reload
        print_success "Systemd service file removed"
    fi
else
    # macOS - kill process if running
    if [ -f /tmp/24fire-automation.pid ]; then
        print_status "Stopping running process..."
        if kill -0 $(cat /tmp/24fire-automation.pid) 2>/dev/null; then
            kill $(cat /tmp/24fire-automation.pid)
            print_success "Process stopped"
        fi
        rm -f /tmp/24fire-automation.pid
    fi
fi

# Remove CLI management script
if [ -f "$CLI_SCRIPT" ]; then
    print_status "Removing CLI management script..."
    sudo rm -f "$CLI_SCRIPT"
    print_success "CLI script removed"
fi

# Remove application directory
if [ -d "$APP_DIR" ]; then
    print_status "Removing application directory: $APP_DIR"
    if [ "$OS" = "macos" ]; then
        rm -rf "$APP_DIR"
    else
        sudo rm -rf "$APP_DIR"
    fi
    print_success "Application directory removed"
fi

# Remove log directory (Linux only)
if [ "$OS" != "macos" ] && [ -d "/var/log/24fire-automation" ]; then
    print_status "Removing log directory..."
    sudo rm -rf "/var/log/24fire-automation"
    print_success "Log directory removed"
fi

# Remove temporary files
if [ -f /tmp/24fire-automation.log ]; then
    print_status "Removing temporary log file..."
    rm -f /tmp/24fire-automation.log
    print_success "Temporary files removed"
fi

# Optional: Remove Python packages (only if they were installed specifically for this)
echo ""
print_warning "Python packages installed during installation are still present."
echo "These packages might be used by other applications:"
echo "  - fastapi, uvicorn, aiohttp, psutil, APScheduler, pydantic, PyYAML, etc."
echo ""

if [ -t 0 ]; then
    read -p "Do you want to remove these Python packages? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing Python packages..."
        
        # Try to remove packages globally (might require sudo)
        PACKAGES="fastapi uvicorn aiohttp psutil APScheduler pydantic PyYAML python-multipart websockets requests"
        
        if command -v pip3 &> /dev/null; then
            for package in $PACKAGES; do
                if pip3 show "$package" &> /dev/null; then
                    print_status "Removing $package..."
                    pip3 uninstall -y "$package" 2>/dev/null || sudo pip3 uninstall -y "$package" 2>/dev/null || true
                fi
            done
            print_success "Python packages removal attempted"
        else
            print_warning "pip3 not found, skipping package removal"
        fi
    fi
fi

# Optional: Remove system packages (be very careful here)
echo ""
print_warning "System packages installed during installation are still present."
echo "These packages might be used by other applications and removing them could break your system."
echo ""

if [ -t 0 ]; then
    read -p "Do you want to see which system packages could be removed? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        print_warning "The following system packages were installed during setup:"
        if [ "$OS" = "debian" ]; then
            echo "  - python3, python3-pip, python3-venv, curl, wget, git"
            echo "  - build-essential, libssl-dev, libffi-dev, python3-dev"
        elif [ "$OS" = "redhat" ]; then
            echo "  - python3, python3-pip, python3-venv, curl, wget, git"
            echo "  - gcc, openssl-devel, libffi-devel, python3-devel"
        elif [ "$OS" = "macos" ]; then
            echo "  - python3, curl, wget, git (via Homebrew)"
        fi
        echo ""
        print_warning "⚠️  DO NOT remove these unless you're sure they're not needed by other applications!"
        echo "To remove them manually (if needed):"
        
        if [ "$OS" = "debian" ]; then
            echo "  sudo apt remove python3-pip python3-venv build-essential libssl-dev libffi-dev python3-dev"
        elif [ "$OS" = "redhat" ]; then
            echo "  sudo yum remove python3-pip python3-venv gcc openssl-devel libffi-devel python3-devel"
            echo "  # or: sudo dnf remove python3-pip python3-venv gcc openssl-devel libffi-devel python3-devel"
        elif [ "$OS" = "macos" ]; then
            echo "  brew uninstall python3 curl wget git"
        fi
    fi
fi

# Clean up any remaining traces
print_status "Cleaning up remaining traces..."

# Remove any remaining configuration files in user's home directory
if [ -f "$HOME/.24fire-automation" ]; then
    rm -f "$HOME/.24fire-automation"
fi

# Remove any cached files
if [ -d "$HOME/.cache/24fire-automation" ]; then
    rm -rf "$HOME/.cache/24fire-automation"
fi

echo ""
print_success "✅ 24Fire Automation System has been completely uninstalled!"
echo ""
echo "📋 Summary of what was removed:"
echo "  ✓ Application files and directory"
echo "  ✓ System service (if applicable)"
echo "  ✓ CLI management script"
echo "  ✓ Log files and directories"
echo "  ✓ Configuration files"
echo ""

if [ "$OS" != "macos" ]; then
    echo "🔄 You may want to run 'sudo systemctl daemon-reload' to refresh systemd"
fi

echo ""
echo "Thank you for using 24Fire Automation System! 🔥"
echo ""
echo "If you encountered any issues during uninstallation, please check:"
echo "  - $APP_DIR (should be removed)"
echo "  - $CLI_SCRIPT (should be removed)"
if [ "$OS" != "macos" ]; then
    echo "  - /etc/systemd/system/$SERVICE_NAME.service (should be removed)"
    echo "  - /var/log/24fire-automation (should be removed)"
fi
echo ""
echo "To reinstall in the future, simply run the install.sh script again."
