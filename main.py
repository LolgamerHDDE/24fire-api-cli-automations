import logging
from fastapi import FastAPI, requests
import uvicorn

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

@app.websocket("/register/{trigger}/{action}")
async def register(trigger: str, action: str, requests: requests):
    return

if __name__ == "__main__":
    uvicorn.run(app=app, host="0.0.0.0", port=62599)
