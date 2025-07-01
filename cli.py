#!/usr/bin/env python3
"""
24Fire Automation CLI Tool
"""

import argparse
import json
import requests
import sys
from typing import Dict, Any

API_BASE = "http://localhost:62599"

def make_request(method: str, endpoint: str, data: Dict = None) -> Dict[str, Any]:
    """Make HTTP request to the automation API"""
    url = f"{API_BASE}{endpoint}"
    try:
        if method.upper() == "GET":
            response = requests.get(url)
        elif method.upper() == "POST":
            response = requests.post(url, json=data)
        elif method.upper() == "PUT":
            response = requests.put(url, json=data)
        elif method.upper() == "DELETE":
            response = requests.delete(url)
        else:
            raise ValueError(f"Unsupported method: {method}")
        
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

def list_automations():
    """List all automations"""
    automations = make_request("GET", "/automations")
    
    if not automations:
        print("📋 No automations configured")
        return
    
    print("📋 Configured Automations:")
    print("-" * 50)
    for auto in automations:
        status = "✅ Enabled" if auto["enabled"] else "❌ Disabled"
        print(f"ID: {auto['id']}")
        print(f"Name: {auto['name']}")
        print(f"Trigger: {auto['trigger_type']} - {auto['trigger_config']}")
        print(f"Action: {auto['action_type']}")
        print(f"Status: {status}")
        print("-" * 50)

def create_automation():
    """Interactive automation creation"""
    print("🔧 Create New Automation")
    print("=" * 30)
    
    auto_id = input("Enter automation ID: ")
    name = input("Enter automation name: ")
    
    print("\nTrigger Types:")
    print("1. Time-based (cron)")
    print("2. Usage-based (CPU/Memory/Disk)")
    trigger_choice = input("Select trigger type (1-2): ")
    
    if trigger_choice == "1":
        trigger_type = "time"
        cron = input("Enter cron expression (e.g., '0 2 * * *' for daily at 2 AM): ")
        trigger_config = {"cron": cron}
    elif trigger_choice == "2":
        trigger_type = "usage"
        resource = input("Enter resource type (cpu/memory/disk): ")
        threshold = int(input("Enter threshold percentage: "))
        trigger_config = {"resource": resource, "threshold": threshold}
        if resource == "disk":
            path = input("Enter disk path (default: /): ") or "/"
            trigger_config["path"] = path
    else:
        print("❌ Invalid choice")
        return
    
    print("\nAction Types:")
    print("1. HTTP POST Request")
    print("2. Discord Webhook")
    print("3. System Restart")
    print("4. System Shutdown")
    print("5. Create Backup")
    action_choice = input("Select action type (1-5): ")
    
    action_config = {}
    if action_choice == "1":
        action_type = "http_post"
        url = input("Enter URL: ")
        action_config = {"url": url, "headers": {}, "data": {}}
    elif action_choice == "2":
        action_type = "discord_webhook"
        message = input("Enter message: ")
        action_config = {"message": message}
    elif action_choice == "3":
        action_type = "restart"
    elif action_choice == "4":
        action_type = "shutdown"
    elif action_choice == "5":
        action_type = "backup"
        description = input("Enter backup description: ")
        action_config = {"description": description}
    else:
        print("❌ Invalid choice")
        return
    
    automation = {
        "id": auto_id,
        "name": name,
        "trigger_type": trigger_type,
        "trigger_config": trigger_config,
        "action_type": action_type,
        "action_config": action_config,
        "enabled": True
    }
    
    result = make_request("POST", "/automations", automation)
    print(f"✅ {result['message']}")

def execute_automation(auto_id: str):
    """Execute automation manually"""
    result = make_request("POST", f"/automations/{auto_id}/execute")
    print(f"✅ {result['message']}")

def delete_automation(auto_id: str):
    """Delete automation"""
    result = make_request("DELETE", f"/automations/{auto_id}")
    print(f"✅ {result['message']}")

def show_status():
    """Show system status"""
    status = make_request("GET", "/status")
    
    print("📊 System Status:")
    print("-" * 20)
    print(f"CPU Usage: {status['cpu_percent']:.1f}%")
    print(f"Memory Usage: {status['memory_percent']:.1f}%")
    print(f"Disk Usage: {status['disk_percent']:.1f}%")
    print(f"Active Automations: {status['active_automations']}")
    print(f"Total Automations: {status['total_automations']}")
    print(f"Scheduler Running: {'✅' if status['scheduler_running'] else '❌'}")

def main():
    parser = argparse.ArgumentParser(description="24Fire Automation CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # List command
    subparsers.add_parser("list", help="List all automations")
    
    # Create command
    subparsers.add_parser("create", help="Create new automation")
    
    # Execute command
    execute_parser = subparsers.add_parser("execute", help="Execute automation")
    execute_parser.add_argument("id", help="Automation ID")
    
    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Delete automation")
    delete_parser.add_argument("id", help="Automation ID")
    
    # Status command
    subparsers.add_parser("status", help="Show system status")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    if args.command == "list":
        list_automations()
    elif args.command == "create":
        create_automation()
    elif args.command == "execute":
        execute_automation(args.id)
    elif args.command == "delete":
        delete_automation(args.id)
    elif args.command == "status":
        show_status()

if __name__ == "__main__":
    main()