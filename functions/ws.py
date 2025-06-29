from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import asyncio
import json
import logging
from typing import List
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="24Fire WebSocket Server", version="1.0.0")

#@app.websocket("")

if __name__ == "__main__":
    logger.info("Starting 24Fire WebSocket Server on port 65432...")
    uvicorn.run(
        "ws:app",
        host="0.0.0.0",
        port=65432,
        log_level="info",
        reload=True
    )
