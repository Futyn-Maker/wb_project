#!/bin/bash

# Stop script if any command fails
set -e

# Configuration
ENV_FILE=".env"
REQUIREMENTS_FILE="requirements.txt"

# Load environment variables
if [ -f $ENV_FILE ]; then
    export $(grep -v '^#' $ENV_FILE | xargs)
else
    echo "Environment file .env does not exist."
    exit 1
fi

# --- Setup Python Environment ---

# Check if virtual environment already exists
if [ ! -d "venv" ]; then
    echo "Setting up Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    echo "Installing Python dependencies..."
    pip install -r $REQUIREMENTS_FILE
else
    echo "Virtual environment already exists. Activating..."
    source venv/bin/activate
fi

# --- Database Setup ---

# Check for PostgreSQL and install if it's not installed
if ! command -v psql > /dev/null; then
    echo "PostgreSQL is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y postgresql-15 postgresql-contrib-15 postgresql-server-dev-15
fi

# Parse the database connection string
DB_USER=$(echo $PG_CONN_STR | sed -n 's/.*\/\/\([^:]*\):.*/\1/p')
DB_PASS=$(echo $PG_CONN_STR | sed -n 's/.*\/\/[^:]*:\([^@]*\)@.*/\1/p')
DB_HOST=$(echo $PG_CONN_STR | sed -n 's/.*@\(.*\):.*/\1/p')
DB_PORT=$(echo $PG_CONN_STR | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
DB_NAME=$(echo $PG_CONN_STR | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Check if PostgreSQL user exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    echo "Creating PostgreSQL user..."
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
else
    echo "PostgreSQL user $DB_USER already exists."
fi

# Check if database exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    echo "Creating database..."
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' LOCALE='C.utf8' TEMPLATE='template0';"
else
    echo "Database $DB_NAME already exists."
fi

# Check for PGVector and install if necessary
if ! sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;" | grep -q 'CREATE EXTENSION'; then
    echo "PGVector is not installed. Installing..."
    sudo apt-get install -y build-essential git  # Installs make and git if they are not available
    cd /tmp
    git clone --branch v0.7.0 https://github.com/pgvector/pgvector.git
    cd pgvector
    make
    sudo make install
    cd -
    sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION vector;"
else
    echo "PGVector extension already installed in $DB_NAME."
fi

# --- Data Preparation ---

echo "Running data preparation scripts..."
python3 scripts/init_db.py
python3 scripts/clean_data.py
python3 scripts/import_qa_pairs.py
python3 scripts/prepare_data.py
python3 scripts/create_embeddings.py

# --- Download Language Model ---

# Check for wget and install if it's not installed
if ! command -v wget > /dev/null; then
    echo "wget is not installed. Installing..."
    sudo apt-get install -y wget
fi

echo "Downloading language model..."
wget https://huggingface.co/Futyn-Maker/saiga_llama3_8b_wildberries_4bit_gguf/resolve/main/saiga_llama3_8b_wildberries_4bit_gguf-unsloth.Q4_K_M.gguf

echo "Setup complete. The environment is ready for use."
