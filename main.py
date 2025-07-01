import logging
import asyncio
import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from fastapi import FastAPI, WebSocket, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse
import uvicorn
import aiohttp
import psutil
import subprocess
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from pydantic import BaseModel
import yaml

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="24Fire Automation System", version="1.0.0")
scheduler = AsyncIOScheduler()

# Configuration
CONFIG_FILE = "config.yaml"
AUTOMATIONS_FILE = "automations.json"

class AutomationConfig(BaseModel):
    id: str
    name: str
    trigger_type: str  # "time", "usage"
    trigger_config: Dict
    action_type: str  # "http_post", "discord_webhook", "restart", "shutdown", "backup"
    action_config: Dict
    enabled: bool = True

class Config:
    def __init__(self):
        self.api_key = os.getenv("FIRE24_API_KEY", "")
        self.internal_id = os.getenv("FIRE24_INTERNAL_ID", "")
        self.discord_webhook_url = os.getenv("DISCORD_WEBHOOK_URL", "")
        self.load_config()
    
    def load_config(self):
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                config_data = yaml.safe_load(f)
                self.api_key = config_data.get('api_key', self.api_key)
                self.internal_id = config_data.get('internal_id', self.internal_id)
                self.discord_webhook_url = config_data.get('discord_webhook_url', self.discord_webhook_url)

config = Config()

class AutomationManager:
    def __init__(self):
        self.automations: Dict[str, AutomationConfig] = {}
        self.load_automations()
    
    def load_automations(self):
        if os.path.exists(AUTOMATIONS_FILE):
            with open(AUTOMATIONS_FILE, 'r') as f:
                data = json.load(f)
                for auto_data in data:
                    automation = AutomationConfig(**auto_data)
                    self.automations[automation.id] = automation
                    if automation.enabled:
                        self.schedule_automation(automation)
    
    def save_automations(self):
        data = [auto.dict() for auto in self.automations.values()]
        with open(AUTOMATIONS_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    
    def schedule_automation(self, automation: AutomationConfig):
        if automation.trigger_type == "time":
            trigger_config = automation.trigger_config
            if "cron" in trigger_config:
                # Cron format: minute hour day month day_of_week
                cron_parts = trigger_config["cron"].split()
                trigger = CronTrigger(
                    minute=cron_parts[0] if len(cron_parts) > 0 else "*",
                    hour=cron_parts[1] if len(cron_parts) > 1 else "*",
                    day=cron_parts[2] if len(cron_parts) > 2 else "*",
                    month=cron_parts[3] if len(cron_parts) > 3 else "*",
                    day_of_week=cron_parts[4] if len(cron_parts) > 4 else "*"
                )
                scheduler.add_job(
                    self.execute_automation,
                    trigger,
                    args=[automation],
                    id=automation.id,
                    replace_existing=True
                )
        elif automation.trigger_type == "usage":
            # For usage-based triggers, we'll check periodically
            scheduler.add_job(
                self.check_usage_trigger,
                'interval',
                minutes=5,
                args=[automation],
                id=f"usage_{automation.id}",
                replace_existing=True
            )
    
    async def check_usage_trigger(self, automation: AutomationConfig):
        trigger_config = automation.trigger_config
        threshold = trigger_config.get("threshold", 80)
        resource_type = trigger_config.get("resource", "cpu")  # cpu, memory, disk
        
        if resource_type == "cpu":
            current_usage = psutil.cpu_percent(interval=1)
        elif resource_type == "memory":
            current_usage = psutil.virtual_memory().percent
        elif resource_type == "disk":
            disk_path = trigger_config.get("path", "/")
            current_usage = psutil.disk_usage(disk_path).percent
        else:
            return
        
        if current_usage >= threshold:
            await self.execute_automation(automation)
    
    async def execute_automation(self, automation: AutomationConfig):
        logger.info(f"Executing automation: {automation.name}")
        
        try:
            if automation.action_type == "http_post":
                await self.execute_http_post(automation.action_config)
            elif automation.action_type == "discord_webhook":
                await self.execute_discord_webhook(automation.action_config)
            elif automation.action_type == "restart":
                await self.execute_restart()
            elif automation.action_type == "shutdown":
                await self.execute_shutdown()
            elif automation.action_type == "backup":
                await self.execute_backup(automation.action_config)
        except Exception as e:
            logger.error(f"Error executing automation {automation.name}: {e}")
    
    async def execute_http_post(self, action_config: Dict):
        url = action_config.get("url")
        headers = action_config.get("headers", {})
        data = action_config.get("data", {})
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, json=data) as response:
                logger.info(f"HTTP POST to {url} - Status: {response.status}")
    
    async def execute_discord_webhook(self, action_config: Dict):
        webhook_url = action_config.get("url", config.discord_webhook_url)
        message = action_config.get("message", "Automation triggered")
        
        payload = {
            "content": message,
            "embeds": [{
                "title": "24Fire Automation",
                "description": message,
                "color": 0x00ff00,
                "timestamp": datetime.utcnow().isoformat()
            }]
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(webhook_url, json=payload) as response:
                logger.info(f"Discord webhook sent - Status: {response.status}")
    
    async def execute_restart(self):
        logger.info("Executing system restart")
        subprocess.run(["sudo", "reboot"], check=False)
    
    async def execute_shutdown(self):
        logger.info("Executing system shutdown")
        subprocess.run(["sudo", "shutdown", "-h", "now"], check=False)
    
    async def execute_backup(self, action_config: Dict):
        description = action_config.get("description", f"Automated backup {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        url = f"https://manage.24fire.de/api/kvm/{config.internal_id}/backup/create"
        headers = {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-Fire-Apikey": config.api_key
        }
        data = f"description={description}"
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, data=data) as response:
                if response.status == 200:
                    logger.info(f"Backup created successfully: {description}")
                else:
                    logger.error(f"Backup creation failed - Status: {response.status}")

automation_manager = AutomationManager()

@app.on_event("startup")
async def startup_event():
    scheduler.start()
    logger.info("24Fire Automation System started")

@app.on_event("shutdown")
async def shutdown_event():
    scheduler.shutdown()

@app.get("/")
async def root():
    return HTMLResponse("""
    <html>
        <head><title>24Fire Automation System</title></head>
        <body>
            <h1>24Fire Automation System</h1>
            <p>Server is running. Use the API endpoints to manage automations.</p>
            <h2>Available Endpoints:</h2>
            <ul>
                <li>GET /automations - List all automations</li>
                <li>POST /automations - Create new automation</li>
                <li>PUT /automations/{id} - Update automation</li>
                <li>DELETE /automations/{id} - Delete automation</li>
                <li>POST /automations/{id}/execute - Execute automation manually</li>
                <li>GET /status - System status</li>
            </ul>
        </body>
    </html>
    """)

@app.get("/automations")
async def list_automations():
    return list(automation_manager.automations.values())

@app.post("/automations")
async def create_automation(automation: AutomationConfig):
    automation_manager.automations[automation.id] = automation
    automation_manager.save_automations()
    
    if automation.enabled:
        automation_manager.schedule_automation(automation)
    
    return {"message": "Automation created successfully", "id": automation.id}

@app.put("/automations/{automation_id}")
async def update_automation(automation_id: str, automation: AutomationConfig):
    if automation_id not in automation_manager.automations:
        raise HTTPException(status_code=404, detail="Automation not found")
    
    # Remove old scheduled job
    try:
        scheduler.remove_job(automation_id)
    except:
        pass
    
    automation_manager.automations[automation_id] = automation
    automation_manager.save_automations()
    
    if automation.enabled:
        automation_manager.schedule_automation(automation)
    
    return {"message": "Automation updated successfully"}

@app.delete("/automations/{automation_id}")
async def delete_automation(automation_id: str):
    if automation_id not in automation_manager.automations:
        raise HTTPException(status_code=404, detail="Automation not found")
    
    # Remove scheduled job
    try:
        scheduler.remove_job(automation_id)
    except:
        pass
    
    del automation_manager.automations[automation_id]
    automation_manager.save_automations()
    
    return {"message": "Automation deleted successfully"}

@app.post("/automations/{automation_id}/execute")
async def execute_automation(automation_id: str, background_tasks: BackgroundTasks):
    if automation_id not in automation_manager.automations:
        raise HTTPException(status_code=404, detail="Automation not found")
    
    automation = automation_manager.automations[automation_id]
    background_tasks.add_task(automation_manager.execute_automation, automation)
    
    return {"message": "Automation execution started"}

@app.get("/status")
async def system_status():
    return {
        "cpu_percent": psutil.cpu_percent(interval=1),
        "memory_percent": psutil.virtual_memory().percent,
        "disk_percent": psutil.disk_usage("/").percent,
        "active_automations": len([a for a in automation_manager.automations.values() if a.enabled]),
        "total_automations": len(automation_manager.automations),
        "scheduler_running": scheduler.running
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Send system status every 30 seconds
            status = {
                "timestamp": datetime.now().isoformat(),
                "cpu_percent": psutil.cpu_percent(interval=1),
                "memory_percent": psutil.virtual_memory().percent,
                "disk_percent": psutil.disk_usage("/").percent,
            }
            await websocket.send_json(status)
            await asyncio.sleep(30)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")

if __name__ == "__main__":
    uvicorn.run(app=app, host="0.0.0.0", port=62599)
