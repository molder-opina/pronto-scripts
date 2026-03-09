#!/bin/bash

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_SCRIPT="$PROJECT_ROOT/bin/python/validate_static_content.py"

# Execute the Python validation script
if [ -f "$PYTHON_SCRIPT" ]; then
    echo "Starting Static Content Validation..."
    python3 "$PYTHON_SCRIPT"
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "Validation Successful!"
    else
        echo "Validation Failed!"
    fi

    exit $EXIT_CODE
else
    echo "Error: Python validation script not found at $PYTHON_SCRIPT"
    exit 1
fi
