# Contributing to 24fire-api-cli-automations

Thank you for your interest in contributing to the 24fire-api-cli-automations project! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Making Changes](#making-changes)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)
- [API Guidelines](#api-guidelines)

## Getting Started

This project is a FastAPI-based automation API that handles triggers and actions through WebSocket connections.

### Prerequisites

- Python 3.7+
- pip or pipenv for package management
- Git

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/LolgamerHDDE/24fire-api-cli-automations.git
   cd 24fire-api-cli-automations
   ```

2. **Create a virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install fastapi uvicorn websockets
   ```

4. **Run the development server**
   ```bash
   python main.py
   ```

The API will be available at `http://localhost:62599`

## Code Style

### Python Code Standards

- Follow PEP 8 style guidelines
- Use meaningful variable and function names
- Add docstrings to functions and classes
- Keep functions focused and concise
- Use type hints where appropriate

### Example:
```python
from typing import Optional
import logging

async def process_automation(trigger: str, action: str) -> Optional[dict]:
    """
    Process automation trigger and action.
    
    Args:
        trigger: The trigger event name
        action: The action to execute
        
    Returns:
        Optional[dict]: Result of the automation process
    """
    logger.info(f"Processing trigger: {trigger}, action: {action}")
    # Implementation here
    return {"status": "success"}
```

## Making Changes

### Before You Start

1. Check existing issues and pull requests to avoid duplicates
2. Create an issue to discuss major changes before implementing
3. Fork the repository and create a feature branch

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, documented code
   - Add tests if applicable
   - Update documentation as needed

3. **Test your changes**
   ```bash
   python main.py
   # Test the WebSocket endpoint manually or with automated tests
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add description of your changes"
   ```

### Commit Message Format

Use conventional commit format:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `refactor:` for code refactoring
- `test:` for adding tests
- `chore:` for maintenance tasks

## Submitting Changes

1. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a Pull Request**
   - Provide a clear title and description
   - Reference any related issues
   - Include screenshots if UI changes are involved
   - Ensure all checks pass

3. **Code Review Process**
   - Address feedback promptly
   - Keep discussions constructive
   - Update your PR based on review comments

## Reporting Issues

When reporting bugs or requesting features:

### Bug Reports
Include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Python version, OS, etc.)
- Error logs if applicable

### Feature Requests
Include:
- Clear description of the proposed feature
- Use case and benefits
- Possible implementation approach

## API Guidelines

### WebSocket Endpoints

When adding new WebSocket endpoints:

1. **Follow the existing pattern**
   ```python
   @app.websocket("/endpoint/{param1}/{param2}")
   async def endpoint_handler(param1: str, param2: str, websocket: WebSocket):
       await websocket.accept()
       # Implementation
   ```

2. **Handle errors gracefully**
   ```python
   try:
       # WebSocket logic
   except WebSocketDisconnect:
       logger.info("Client disconnected")
   except Exception as e:
       logger.error(f"Error in WebSocket handler: {e}")
   ```

3. **Add proper logging**
   ```python
   logger.info(f"WebSocket connection established for {param1}/{param2}")
   ```

### Adding New Triggers/Actions

1. Document the trigger/action in the code
2. Add validation for parameters
3. Include error handling
4. Update API documentation

## Testing

### Manual Testing
1. Start the server: `python main.py`
2. Test WebSocket connections using tools like:
   - WebSocket client tools
   - Browser developer console
   - Python WebSocket client

### Automated Testing (Future)
We welcome contributions to add automated testing:
- Unit tests with pytest
- Integration tests for WebSocket endpoints
- API endpoint testing

## Documentation

- Update README.md if adding new features
- Add inline code documentation
- Update API documentation for new endpoints

## Questions and Support

- Create an issue for questions about contributing
- Check existing issues and discussions
- Be respectful and constructive in all interactions

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to 24fire-api-cli-automations! 🚀