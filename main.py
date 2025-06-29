import asyncio
import websockets
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_websocket_client():
    uri = "ws://localhost:65432/ws/12345"
    
    try:
        async with websockets.connect(uri) as websocket:
            logger.info("Connected to WebSocket server")
            
            # Send a test message
            test_message = {
                "action": "test",
                "data": "Hello from 24Fire client!",
                "timestamp": asyncio.get_event_loop().time()
            }
            
            await websocket.send(json.dumps(test_message))
            logger.info(f"Sent: {test_message}")
            
            # Listen for messages
            try:
                while True:
                    message = await websocket.recv()
                    data = json.loads(message)
                    logger.info(f"Received: {data}")
                    
            except websockets.exceptions.ConnectionClosed:
                logger.info("Connection closed")
                
    except Exception as e:
        logger.error(f"Error connecting to WebSocket: {e}")

if __name__ == "__main__":
    asyncio.run(test_websocket_client())
