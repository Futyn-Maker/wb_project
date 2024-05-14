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
fi

echo "Activating virtual environment..."
source venv/bin/activate

pip3 install -r $REQUIREMENTS_FILE

# --- Database Setup ---

# Check for PostgreSQL and install if it's not installed
if ! command -v psql > /dev/null; then
    echo "PostgreSQL is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y postgresql-15 postgresql-contrib-15
fi

# Check if development files are installed
if ! dpkg -s postgresql-server-dev-15 > /dev/null; then
    echo "PostgreSQL dev files are not installed. Installing..."
    sudo apt-get install -y postgresql-server-dev-15
fi

# Run PostgreSQL
sudo service postgresql start

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
    cd -
    sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION vector;"
else
    echo "PGVector extension already installed in $DB_NAME."
fi

# init database
echo "Initializing database..."
python3 scripts/init_db.py

# --- Data Preparation ---

# Preparing to run data scripts
echo "Preparing to run data scripts..."

# Check for data files before running clean_data.py
if [ ! -f "data/knowledge_base.xlsx" ] || [ ! -f "data/QA_pairs.xlsx" ]; then
    echo "Required data files are missing. Exiting..."
    exit 1
fi

if [ -f "data/qa_pairs_cleaned.csv" ] || [ -f "data/kb_chunks_cleaned.csv" ]; then
    read -p "Cleaned data files already exist. Overwrite them? (y/n): " overwrite
    if [ "$overwrite" != "y" ]; then
        echo "Skipping clean_data.py..."
        skip_clean_data="true"
    fi
fi

if [ "$skip_clean_data" != "true" ]; then
    echo "Running clean_data.py..."
    python3 scripts/clean_data.py
fi

echo "Running import_qa_pairs.py..."
python3 scripts/import_qa_pairs.py

echo "Running prepare_data.py..."
python3 scripts/prepare_data.py

# Check if haystack_documents table is not empty before running create_embeddings.py
if sudo -u postgres psql -d $DB_NAME -tAc "SELECT EXISTS (SELECT 1 FROM haystack_documents LIMIT 1);" | grep -q 't'; then
    read -p "Haystack documents table is not empty. Overwrite embeddings? (y/n): " overwrite_embeddings
    if [ "$overwrite_embeddings" != "y" ]; then
        echo "Skipping create_embeddings.py..."
        skip_embeddings="true"
    fi
fi

if [ "$skip_embeddings" != "true" ]; then
    echo "Running create_embeddings.py..."
    python3 scripts/create_embeddings.py
fi

# --- Download Language Model ---

MODEL_FILE="saiga_llama3_8b_wildberries_4bit_gguf-unsloth.Q4_K_M.gguf"

if [ -f "$MODEL_FILE" ]; then
    read -p "Model file $MODEL_FILE already exists. Download again? (y/n): " download_again
    if [ "$download_again" != "y" ]; then
        echo "Skipping model download..."
        skip_model_download="true"
    fi
fi

if [ "$skip_model_download" != "true" ]; then
    echo "Downloading language model..."
    wget https://huggingface.co/Futyn-Maker/saiga_llama3_8b_wildberries_4bit_gguf/resolve/main/saiga_llama3_8b_wildberries_4bit_gguf-unsloth.Q4_K_M.gguf
fi

echo "Setup complete. The environment is ready for use."
