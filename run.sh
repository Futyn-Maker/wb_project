#!/bin/bash

# Stop the script if any command fails
set -e

# Configuration
ENV_FILE=".env"
APP_MODULE="app.main:app"  # Format: module_name:app_instance
HOST="0.0.0.0"
PORT="8000"

# Activate the virtual environment
echo "Activating the virtual environment..."
source venv/bin/activate

# Load environment variables
if [ -f $ENV_FILE ]; then
    export $(grep -v '^#' $ENV_FILE | xargs)
else
    echo "Environment file .env does not exist."
    echo "Please create one based on .env.example and try again."
    exit 1
fi

# Start the FastAPI application
echo "Starting the FastAPI application..."
uvicorn $APP_MODULE --host $HOST --port $PORT --reload

echo "FastAPI application is running at http://$HOST:$PORT"
