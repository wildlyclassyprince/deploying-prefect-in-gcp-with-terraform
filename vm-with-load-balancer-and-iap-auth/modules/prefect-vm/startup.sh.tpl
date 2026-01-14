#!/bin/bash --

# Log all output
exec > >(tee /var/log/startup.log)
exec 2>&1

echo "Starting startup script at $(date)"

# Update the VM instance on startup
apt-get update
apt-get upgrade -y

# Install Google Cloud Ops Agent (replaces legacy logging/monitoring agents)
echo "Installing Google Cloud Ops Agent..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
rm add-google-cloud-ops-agent-repo.sh

# Install Docker
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    git \
    build-essential \
    fuse \
    postgresql \
    postgresql-contrib

# Create prefect user with admin permissions
echo "Create 'prefect' user ..."
useradd -m -s /bin/bash -G sudo prefect
echo "prefect:$(openssl rand -base64 32)" | chpasswd

# Set up Python environment for prefect user
echo "Setting up Python environment..."
echo "Switching to prefect user..."
sudo -u prefect -i <<EOF
  echo "Installing and setting up uv ..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="\$HOME/.local/bin:\$PATH"
  uv venv --python 3.13
  . /home/prefect/.venv/bin/activate

  echo "Installing Prefect..."
  uv pip install prefect
  echo "Prefect installed successfully"
EOF

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create a PostgreSQL database for Prefect
sudo -u postgres psql -c "CREATE DATABASE prefect;"
sudo -u postgres psql -c "CREATE USER prefect WITH PASSWORD '${prefect_postgres_password}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE prefect TO prefect;"

# Grant schema-level privileges (required for PostgreSQL 15+)
sudo -u postgres psql -d prefect -c "GRANT ALL ON SCHEMA public TO prefect;"
sudo -u postgres psql -d prefect -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO prefect;"
sudo -u postgres psql -d prefect -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO prefect;"
sudo -u postgres psql -d prefect -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO prefect;"
sudo -u postgres psql -d prefect -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO prefect;"

# Configure PostgreSQL to only listen on localhost for security
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/*/main/postgresql.conf

# Update pg_hba.conf to allow password authentication for prefect user
echo "local    prefect    prefect    md5" >> /etc/postgresql/*/main/pg_hba.conf

# Restart PostgreSQL to apply changes
systemctl restart postgresql

echo "PostgreSQL configured successfully for Prefect"

# Configure Cloud Ops Agent to collect Prefect logs
cat > /etc/google-cloud-ops-agent/config.yaml << 'OPSCONFIG'
logging:
  receivers:
    # Collect Prefect server logs from systemd journal
    prefect_server:
      type: systemd_journald
      units:
        - prefect-server
    
    # Collect Prefect worker logs from systemd journal
    prefect_worker:
      type: systemd_journald
      units:
        - prefect-test-worker
    
    # Collect PostgreSQL logs
    postgresql:
      type: files
      include_paths:
        - /var/log/postgresql/postgresql-*.log
    
    # Collect startup script logs
    startup_logs:
      type: files
      include_paths:
        - /var/log/startup.log
  
  processors:
    # Parse Prefect logs as JSON if possible
    prefect_parser:
      type: parse_json
      field: message
      time_key: timestamp
      time_format: "%Y-%m-%dT%H:%M:%S"
  
  service:
    pipelines:
      prefect_server_pipeline:
        receivers:
          - prefect_server
        processors:
          - prefect_parser
      
      prefect_worker_pipeline:
        receivers:
          - prefect_worker
        processors:
          - prefect_parser
      
      postgresql_pipeline:
        receivers:
          - postgresql
      
      startup_pipeline:
        receivers:
          - startup_logs

metrics:
  receivers:
    # Collect host metrics (CPU, memory, disk, network)
    hostmetrics:
      type: hostmetrics
      collection_interval: 60s
  
  service:
    pipelines:
      default_pipeline:
        receivers:
          - hostmetrics
OPSCONFIG

# Restart Ops Agent to apply configuration
echo "Restarting Cloud Ops Agent with Prefect logging configuration..."
systemctl restart google-cloud-ops-agent
echo "Cloud Ops Agent configured successfully"

# Setup environment variables
cat > /etc/profile.d/prefect.sh << EOF
# Prefect environment variables
export PATH=/home/prefect/.venv/bin:/usr/local/bin:/usr/bin:/bin
export VIRTUAL_ENV=/home/prefect/venv
export PREFECT_API_URL=http://localhost:4200/api
export PREFECT_HOME=/home/prefect/.prefect
EOF
sudo chmod +x /etc/profile.d/prefect.sh


# Run Prefect server as a systemd service
cat > /etc/systemd/system/prefect-server.service << EOF
[Unit]
Description=Prefect Server
After=network.target
Wants=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=prefect
Group=prefect
Restart=always
RestartSec=10
WorkingDirectory=/home/prefect

# Environment variables
Environment=PATH=/home/prefect/.venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=VIRTUAL_ENV=/home/prefect/venv
Environment=PREFECT_API_URL=http://localhost:4200/api
Environment=PREFECT_HOME=/home/prefect/.prefect
Environment=PREFECT_API_DATABASE_CONNECTION_URL=postgresql+asyncpg://prefect:${prefect_postgres_password}@localhost:5432/prefect

# Pre-start cleanup commands
ExecStartPre=/bin/bash -c 'mkdir -p /home/prefect/.prefect'
ExecStartPre=/bin/bash -c 'chown -R prefect:prefect /home/prefect/.prefect'

# Start Prefect server
ExecStart=/home/prefect/.venv/bin/prefect server start --host 0.0.0.0

# Restart on failure
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

EOF

# Prefect test worker
cat > /etc/systemd/system/prefect-test-worker.service << EOF
[Unit]
Description=Prefect Test Worker
After=network.target.prefect-server.service
Wants=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=prefect
Group=prefect
Restart=always
RestartSec=10
WorkingDirectory=/home/prefect

# Environment variables
Environment=PATH=/home/prefect/.venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=VIRTUAL_ENV=/home/prefect/venv
Environment=PREFECT_API_URL=http://localhost:4200/api
Environment=PREFECT_HOME=/home/prefect/.prefect
Environment=PREFECT_API_DATABASE_CONNECTION_URL=postgresql+asyncpg://prefect:${prefect_postgres_password}@localhost:5432/prefect

# Start Prefect test worker
# The sequence of commands matters: first create the pool, then the queue, before starting the worker
ExecStartPre=/bin/bash -c 'source /home/prefect/.venv/bin/activate && prefect work-pool create "Test Flow Pool" -t process && prefect work-queue pause "default" -p "Test Flow Pool" && prefect work-queue create "test_hourly" -p "Test Flow Pool" -l 5 -q 1'
ExecStart=/bin/bash -c 'source /home/prefect/.venv/bin/activate && prefect worker start --work-queue "test_hourly" -p "Test Flow Pool" -l 5'


# Restart on failure
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

EOF



# Enable Prefect server
echo "Enabling Prefect server ..."
systemctl daemon-reload
systemctl enable prefect-server
systemctl start prefect-server
sleep 15

# Enable Prefect test worker
echo "Enabling Prefect test worker ..."
systemctl enable prefect-test-worker
systemctl start prefect-test-worker

echo "Startup script completed at $(date)"
