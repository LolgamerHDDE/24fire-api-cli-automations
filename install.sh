#!/bin/bash

# 24Fire Automation System Installer
echo "🔥 24Fire Automation System Installer"
echo "======================================"

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   echo "Please run as a regular user with sudo privileges"
   exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    print_error "sudo is required but not installed"
    exit 1
fi

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

# Update system packages
print_status "Updating system packages..."
if [ "$OS" = "debian" ]; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y python3 python3-pip python3-venv curl wget git build-essential libssl-dev libffi-dev python3-dev
elif [ "$OS" = "redhat" ]; then
    sudo yum update -y || sudo dnf update -y
    sudo yum install -y python3 python3-pip python3-venv curl wget git gcc openssl-devel libffi-devel python3-devel || \
    sudo dnf install -y python3 python3-pip python3-venv curl wget git gcc openssl-devel libffi-devel python3-devel
elif [ "$OS" = "macos" ]; then
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is required on macOS. Please install it first:"
        echo "https://brew.sh"
        exit 1
    fi
    brew update
    brew install python3 curl wget git
fi

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    print_error "Python 3.8+ is required. Found: $PYTHON_VERSION"
    exit 1
fi

print_status "Python version check passed: $PYTHON_VERSION"

# Create application directory
APP_DIR="/opt/24fire-automation"
if [ "$OS" = "macos" ]; then
    APP_DIR="$HOME/24fire-automation"
fi

print_status "Creating application directory: $APP_DIR"
if [ "$OS" = "macos" ]; then
    mkdir -p $APP_DIR
else
    sudo mkdir -p $APP_DIR
    sudo chown $USER:$USER $APP_DIR
fi

# Copy application files
print_status "Setting up application files..."
cd $APP_DIR

# Create main.py if it doesn't exist
if [ ! -f main.py ]; then
    print_status "Creating main application file..."
    # The main.py content would be created here
    # For now, we'll assume it exists in the current directory
    if [ -f ../main.py ]; then
        cp ../main.py .
    fi
fi

# Create Python virtual environment
print_status "Creating Python virtual environment..."
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
print_status "Upgrading pip..."
pip install --upgrade pip

# Create requirements.txt
print_status "Creating requirements.txt..."
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
aiohttp==3.9.1
psutil==5.9.6
APScheduler==3.10.4
pydantic==2.5.0
PyYAML==6.0.1
python-multipart==0.0.6
websockets==12.0
requests==2.31.0
EOF

# Install Python dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt

# Test imports
print_status "Testing Python imports..."
python3 -c "
import aiohttp
import psutil
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import yaml
import fastapi
import uvicorn
print('✅ All imports successful!')
" || {
    print_error "Failed to import required modules"
    exit 1
}

# Create configuration files
print_status "Creating configuration files..."

# Create config.yaml
if [ ! -f config.yaml ]; then
    cat > config.yaml << 'EOF'
# 24Fire API Configuration
api_key: "YOUR_API_KEY_HERE"
internal_id: "YOUR_INTERNAL_ID_HERE"
discord_webhook_url: "YOUR_DISCORD_WEBHOOK_URL_HERE"

# Server Configuration
host: "0.0.0.0"
port: 62599
log_level: "INFO"
EOF
fi

# Create automations.json
if [ ! -f automations.json ]; then
    cat > automations.json << 'EOF'
[
  {
    "id": "daily_backup",
    "name": "Daily Backup",
    "trigger_type": "time",
    "trigger_config": {
      "cron": "0 2 * * *"
    },
    "action_type": "backup",
    "action_config": {
      "description": "Daily automated backup"
    },
    "enabled": true
  },
  {
    "id": "high_cpu_alert",
    "name": "High CPU Usage Alert",
    "trigger_type": "usage",
    "trigger_config": {
      "resource": "cpu",
      "threshold": 90
    },
    "action_type": "discord_webhook",
    "action_config": {
      "message": "⚠️ High CPU usage detected! Current usage above 90%"
    },
    "enabled": false
  }
]
EOF
fi

# Create systemd service (Linux only)
if [ "$OS" != "macos" ]; then
    print_status "Creating systemd service..."
    sudo tee /etc/systemd/system/24fire-automation.service > /dev/null << EOF
[Unit]
Description=24Fire Automation System
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Create log directory
    sudo mkdir -p /var/log/24fire-automation
    sudo chown $USER:$USER /var/log/24fire-automation
fi

# Create CLI management script
print_status "Creating CLI management script..."
CLI_SCRIPT="/usr/local/bin/24fire-automation"
if [ "$OS" = "macos" ]; then
    CLI_SCRIPT="/usr/local/bin/24fire-automation"
fi

sudo tee $CLI_SCRIPT > /dev/null << 'EOF'
#!/bin/bash

APP_DIR="/opt/24fire-automation"
SERVICE_NAME="24fire-automation"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    APP_DIR="$HOME/24fire-automation"
    USE_SYSTEMD=false
else
    USE_SYSTEMD=true
fi

case "$1" in
    start)
        echo "🚀 Starting 24Fire Automation System..."
        if [ "$USE_SYSTEMD" = true ]; then
            sudo systemctl start $SERVICE_NAME
        else
            cd $APP_DIR
            source venv/bin/activate
            nohup python main.py > /tmp/24fire-automation.log 2>&1 &
            echo $! > /tmp/24fire-automation.pid
            echo "Started with PID: $(cat /tmp/24fire-automation.pid)"
        fi
        ;;
    stop)
        echo "🛑 Stopping 24Fire Automation System..."
        if [ "$USE_SYSTEMD" = true ]; then
            sudo systemctl stop $SERVICE_NAME
        else
            if [ -f /tmp/24fire-automation.pid ]; then
                kill $(cat /tmp/24fire-automation.pid)
                rm /tmp/24fire-automation.pid
            fi
        fi
        ;;
    restart)
        echo "🔄 Restarting 24Fire Automation System..."
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if [ "$USE_SYSTEMD" = true ]; then
            sudo systemctl status $SERVICE_NAME
        else
            if [ -f /tmp/24fire-automation.pid ] && kill -0 $(cat /tmp/24fire-automation.pid) 2>/dev/null; then
                echo "✅ 24Fire Automation System is running (PID: $(cat /tmp/24fire-automation.pid))"
            else
                echo "❌ 24Fire Automation System is not running"
            fi
        fi
        ;;
    logs)
        if [ "$USE_SYSTEMD" = true ]; then
            sudo journalctl -u $SERVICE_NAME -f
        else
            tail -f /tmp/24fire-automation.log
        fi
        ;;
    enable)
        if [ "$USE_SYSTEMD" = true ]; then
            echo "✅ Enabling 24Fire Automation System to start on boot..."
            sudo systemctl enable $SERVICE_NAME
        else
            echo "ℹ️ Auto-start on boot not supported on this system"
        fi
        ;;
    disable)
        if [ "$USE_SYSTEMD" = true ]; then
            echo "❌ Disabling 24Fire Automation System from starting on boot..."
            sudo systemctl disable $SERVICE_NAME
        else
            echo "ℹ️ Auto-start on boot not supported on this system"
        fi
        ;;
    config)
        echo "📝 Opening configuration file..."
        ${EDITOR:-nano} $APP_DIR/config.yaml
        ;;
    test)
        echo "🧪 Testing system..."
        cd $APP_DIR
        source venv/bin/activate
        python -c "
import aiohttp
import psutil
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import yaml
print('✅ All dependencies working!')
print(f'CPU: {psutil.cpu_percent()}%')
print(f'Memory: {psutil.virtual_memory().percent}%')
"
        ;;
    web)
        echo "🌐 Opening web interface..."
        if command -v xdg-open > /dev/null; then
            xdg-open "http://localhost:62599"
        elif command -v open > /dev/null; then
            open "http://localhost:62599"
        else
            echo "Web interface: http://localhost:62599"
        fi
        ;;
    *)
        echo "24Fire Automation System CLI"
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable|config|test|web}"
        echo ""
        echo "Commands:"
        echo "  start      - Start the automation system"
        echo "  stop       - Stop the automation system"
        echo "  restart    - Restart the automation system"
        echo "  status     - Show service status"
        echo "  logs       - Show live logs"
        echo "  enable     - Enable auto-start on boot (Linux only)"
        echo "  disable    - Disable auto-start on boot (Linux only)"
        echo "  config     - Edit configuration file"
        echo "  test       - Test system dependencies"
        echo "  web        - Open web interface"
        exit 1
        ;;
esac
EOF

sudo chmod +x $CLI_SCRIPT

# Set proper permissions
chmod 600 config.yaml

# Enable and start service (Linux only)
if [ "$OS" != "macos" ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
fi

# Configuration setup
print_status "Setting up configuration..."
echo ""
echo "🔧 Configuration Setup"
echo "======================"

# Check if running interactively
if [ -t 0 ]; then
    read -p "Enter your 24Fire API Key (or press Enter to skip): " API_KEY
    read -p "Enter your 24Fire Internal ID (or press Enter to skip): " INTERNAL_ID
    read -p "Enter Discord Webhook URL (optional): " DISCORD_WEBHOOK

    if [ ! -z "$API_KEY" ] && [ ! -z "$INTERNAL_ID" ]; then
        # Update configuration file
        cat > config.yaml << EOF
# 24Fire API Configuration
api_key: "$API_KEY"
internal_id: "$INTERNAL_ID"
discord_webhook_url: "$DISCORD_WEBHOOK"

# Server Configuration
host: "0.0.0.0"
port: 62599
log_level: "INFO"
EOF
        print_status "Configuration updated successfully!"
    else
        print_warning "Configuration skipped. Edit config.yaml manually later."
    fi
else
    print_warning "Non-interactive mode. Edit config.yaml manually."
fi

echo ""
echo "✅ Installation completed successfully!"
echo ""
echo "🎉 24Fire Automation System is now installed!"
echo ""
echo "Next steps:"
echo "1. Edit configuration: 24fire-automation config"
echo "2. Start the service: 24fire-automation start"
echo "3. Check status: 24fire-automation status"
echo "4. View web interface: http://localhost:62599"
echo ""
echo "CLI Commands available:"
echo "- 24fire-automation start/stop/restart"
echo "- 24fire-automation status/logs"
echo "- 24fire-automation config"
echo "- 24fire-automation backup-now"
echo "- 24fire-automation web"
echo ""
echo "🔥 Happy automating with 24Fire!"
