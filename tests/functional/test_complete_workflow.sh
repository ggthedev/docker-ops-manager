#!/usr/bin/env bash

# Test: Complete workflow functional tests
# Description: Tests the complete end-to-end workflow of the Docker Ops Manager

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test variables
TEST_NAME="test_complete_workflow"
TEST_LOG="$TEST_LOGS_DIR/${TEST_NAME}.log"
MAIN_SCRIPT="$PROJECT_ROOT/docker_ops_manager.sh"

# Test setup
setup_test() {
    echo "Setting up complete workflow test..."
    
    # Create test workspace
    mkdir -p "$TEST_TEMP_DIR/workspace"
    cd "$TEST_TEMP_DIR/workspace"
    
    # Create a complete test application
    cat > "web-app.yml" << 'EOF'
name: web-application
version: "1.0"
description: "Complete web application with frontend, backend, and database"

containers:
  frontend:
    image: nginx:alpine
    ports:
      - "8080:80"
    environment:
      - NGINX_HOST=localhost
      - API_URL=http://backend:3000
    volumes:
      - ./frontend:/usr/share/nginx/html
      - ./nginx.conf:/etc/nginx/nginx.conf
    restart: unless-stopped
    depends_on:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    image: node:18-alpine
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DB_HOST=database
      - DB_PORT=5432
      - DB_NAME=appdb
      - DB_USER=appuser
      - DB_PASSWORD=apppass
    volumes:
      - ./backend:/app
      - backend_data:/app/data
    working_dir: /app
    command: ["sh", "-c", "npm install && npm start"]
    restart: unless-stopped
    depends_on:
      - database
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  database:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=appdb
      - POSTGRES_USER=appuser
      - POSTGRES_PASSWORD=apppass
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 30s
      timeout: 10s
      retries: 3

  cache:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    driver: bridge
  backend:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  backend_data:
    driver: local
  frontend:
    driver: local
EOF

    # Create frontend files
    mkdir -p frontend
    cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Test Web Application</title>
</head>
<body>
    <h1>Test Web Application</h1>
    <p>Frontend is running!</p>
    <div id="status">Loading...</div>
    <script>
        fetch('/api/status')
            .then(response => response.json())
            .then(data => {
                document.getElementById('status').innerHTML = 
                    'Backend Status: ' + data.status;
            })
            .catch(error => {
                document.getElementById('status').innerHTML = 
                    'Error: ' + error.message;
            });
    </script>
</body>
</html>
EOF

    # Create backend files
    mkdir -p backend
    cat > backend/package.json << 'EOF'
{
  "name": "test-backend",
  "version": "1.0.0",
  "description": "Test backend application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "redis": "^4.6.7"
  }
}
EOF

    cat > backend/server.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
const port = 3000;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Redis connection
const redisClient = redis.createClient({
  url: 'redis://cache:6379'
});

redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect();

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Status endpoint
app.get('/api/status', async (req, res) => {
  try {
    // Check database connection
    const dbResult = await pool.query('SELECT NOW()');
    
    // Check Redis connection
    await redisClient.ping();
    
    res.json({ 
      status: 'all systems operational',
      database: 'connected',
      redis: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'error',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Data endpoint
app.get('/api/data', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM test_data ORDER BY id DESC LIMIT 10');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Add data endpoint
app.post('/api/data', async (req, res) => {
  try {
    const { message } = req.body;
    const result = await pool.query(
      'INSERT INTO test_data (message, created_at) VALUES ($1, NOW()) RETURNING *',
      [message]
    );
    
    // Cache the latest data
    await redisClient.set('latest_data', JSON.stringify(result.rows[0]));
    
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Backend server running on port ${port}`);
});
EOF

    # Create database initialization script
    mkdir -p database
    cat > database/init.sql << 'EOF'
-- Initialize database schema
CREATE TABLE IF NOT EXISTS test_data (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some test data
INSERT INTO test_data (message) VALUES 
    ('Initial test message 1'),
    ('Initial test message 2'),
    ('Initial test message 3');
EOF

    # Create nginx configuration
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:3000;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

    echo "Test setup complete"
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up complete workflow test..."
    
    # Stop and remove all test containers
    docker ps -a --filter "name=web-application" --format "{{.ID}}" | xargs -r docker rm -f
    
    # Remove test volumes
    docker volume ls --filter "name=postgres_data" --format "{{.Name}}" | xargs -r docker volume rm
    docker volume ls --filter "name=redis_data" --format "{{.Name}}" | xargs -r docker volume rm
    docker volume ls --filter "name=backend_data" --format "{{.Name}}" | xargs -r docker volume rm
    docker volume ls --filter "name=frontend" --format "{{.Name}}" | xargs -r docker volume rm
    
    # Clean up test files
    cd "$TEST_TEMP_DIR"
    rm -rf workspace
    
    echo "Test cleanup complete"
}

# Test 1: Complete application deployment workflow
test_complete_deployment_workflow() {
    echo "Testing complete application deployment workflow..."
    
    cd "$TEST_TEMP_DIR/workspace"
    
    # Step 1: Generate application
    echo "Step 1: Generating application..."
    local generate_result=$("$MAIN_SCRIPT" generate web-app.yml 2>&1)
    local generate_exit_code=$?
    
    assert_exit_code 0 "$generate_exit_code" "Application generation should succeed"
    assert_contains "$generate_result" "generated" "Generation should report success"
    
    # Step 2: Install application
    echo "Step 2: Installing application..."
    local install_result=$("$MAIN_SCRIPT" install web-app.yml 2>&1)
    local install_exit_code=$?
    
    assert_exit_code 0 "$install_exit_code" "Application installation should succeed"
    assert_contains "$install_result" "installed" "Installation should report success"
    
    # Step 3: Wait for all services to be ready
    echo "Step 3: Waiting for services to be ready..."
    sleep 30
    
    # Step 4: Check application status
    echo "Step 4: Checking application status..."
    local status_result=$("$MAIN_SCRIPT" status web-app.yml 2>&1)
    local status_exit_code=$?
    
    assert_exit_code 0 "$status_exit_code" "Status check should succeed"
    assert_contains "$status_result" "running" "All containers should be running"
    
    # Step 5: Test frontend accessibility
    echo "Step 5: Testing frontend accessibility..."
    local frontend_response=$(curl -s http://localhost:8080 || echo "Connection failed")
    assert_contains "$frontend_response" "Test Web Application" "Frontend should be accessible"
    
    # Step 6: Test backend API
    echo "Step 6: Testing backend API..."
    local backend_health=$(curl -s http://localhost:3000/health || echo "Connection failed")
    assert_contains "$backend_health" "healthy" "Backend health check should pass"
    
    local backend_status=$(curl -s http://localhost:3000/api/status || echo "Connection failed")
    assert_contains "$backend_status" "all systems operational" "Backend status should be operational"
    
    # Step 7: Test database connectivity
    echo "Step 7: Testing database connectivity..."
    local db_data=$(curl -s http://localhost:3000/api/data || echo "Connection failed")
    assert_contains "$db_data" "Initial test message" "Database should contain test data"
    
    # Step 8: Test data insertion
    echo "Step 8: Testing data insertion..."
    local insert_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"message":"Test message from workflow"}' \
        http://localhost:3000/api/data || echo "Connection failed")
    assert_contains "$insert_response" "Test message from workflow" "Data insertion should work"
    
    # Step 9: Test Redis connectivity
    echo "Step 9: Testing Redis connectivity..."
    local redis_test=$(docker exec web-application-cache redis-cli ping 2>/dev/null || echo "Redis failed")
    assert_equals "PONG" "$redis_test" "Redis should respond to ping"
    
    echo "✓ Complete deployment workflow test passed"
}

# Test 2: Application scaling and management
test_application_scaling_management() {
    echo "Testing application scaling and management..."
    
    cd "$TEST_TEMP_DIR/workspace"
    
    # Install application if not already running
    if ! docker ps --filter "name=web-application" --format "{{.Names}}" | grep -q "web-application"; then
        "$MAIN_SCRIPT" install web-app.yml > /dev/null 2>&1
        sleep 30
    fi
    
    # Test restart functionality
    echo "Testing restart functionality..."
    local restart_result=$("$MAIN_SCRIPT" restart web-app.yml 2>&1)
    local restart_exit_code=$?
    
    assert_exit_code 0 "$restart_exit_code" "Application restart should succeed"
    assert_contains "$restart_result" "restarted" "Restart should report success"
    
    # Wait for restart to complete
    sleep 10
    
    # Verify services are still running
    local status_result=$("$MAIN_SCRIPT" status web-app.yml 2>&1)
    assert_contains "$status_result" "running" "Services should be running after restart"
    
    # Test stop and start functionality
    echo "Testing stop and start functionality..."
    local stop_result=$("$MAIN_SCRIPT" stop web-app.yml 2>&1)
    assert_contains "$stop_result" "stopped" "Stop should report success"
    
    local start_result=$("$MAIN_SCRIPT" start web-app.yml 2>&1)
    assert_contains "$start_result" "started" "Start should report success"
    
    # Wait for services to be ready
    sleep 20
    
    # Verify services are running again
    local status_after_start=$("$MAIN_SCRIPT" status web-app.yml 2>&1)
    assert_contains "$status_after_start" "running" "Services should be running after start"
    
    echo "✓ Application scaling and management test passed"
}

# Test 3: Logging and monitoring
test_logging_monitoring() {
    echo "Testing logging and monitoring..."
    
    cd "$TEST_TEMP_DIR/workspace"
    
    # Install application if not already running
    if ! docker ps --filter "name=web-application" --format "{{.Names}}" | grep -q "web-application"; then
        "$MAIN_SCRIPT" install web-app.yml > /dev/null 2>&1
        sleep 30
    fi
    
    # Test application logs
    echo "Testing application logs..."
    local logs_result=$("$MAIN_SCRIPT" logs web-app.yml 2>&1)
    local logs_exit_code=$?
    
    assert_exit_code 0 "$logs_exit_code" "Logs retrieval should succeed"
    assert_contains "$logs_result" "Backend server running" "Backend logs should be present"
    assert_contains "$logs_result" "nginx" "Frontend logs should be present"
    
    # Test individual container logs
    echo "Testing individual container logs..."
    local backend_logs=$(docker logs web-application-backend 2>&1)
    assert_contains "$backend_logs" "Backend server running" "Backend container logs should be present"
    
    local frontend_logs=$(docker logs web-application-frontend 2>&1)
    assert_contains "$frontend_logs" "nginx" "Frontend container logs should be present"
    
    # Test health checks
    echo "Testing health checks..."
    local frontend_health=$(docker inspect web-application-frontend --format='{{.State.Health.Status}}' 2>/dev/null)
    assert_contains "$frontend_health" "healthy" "Frontend health check should pass"
    
    local backend_health=$(docker inspect web-application-backend --format='{{.State.Health.Status}}' 2>/dev/null)
    assert_contains "$backend_health" "healthy" "Backend health check should pass"
    
    local database_health=$(docker inspect web-application-database --format='{{.State.Health.Status}}' 2>/dev/null)
    assert_contains "$database_health" "healthy" "Database health check should pass"
    
    local cache_health=$(docker inspect web-application-cache --format='{{.State.Health.Status}}' 2>/dev/null)
    assert_contains "$cache_health" "healthy" "Cache health check should pass"
    
    echo "✓ Logging and monitoring test passed"
}

# Test 4: Data persistence and backup
test_data_persistence_backup() {
    echo "Testing data persistence and backup..."
    
    cd "$TEST_TEMP_DIR/workspace"
    
    # Install application if not already running
    if ! docker ps --filter "name=web-application" --format "{{.Names}}" | grep -q "web-application"; then
        "$MAIN_SCRIPT" install web-app.yml > /dev/null 2>&1
        sleep 30
    fi
    
    # Add some test data
    echo "Adding test data..."
    curl -s -X POST -H "Content-Type: application/json" \
        -d '{"message":"Persistence test message 1"}' \
        http://localhost:3000/api/data > /dev/null
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d '{"message":"Persistence test message 2"}' \
        http://localhost:3000/api/data > /dev/null
    
    # Verify data was added
    local data_before=$(curl -s http://localhost:3000/api/data)
    assert_contains "$data_before" "Persistence test message" "Test data should be present"
    
    # Restart the application
    echo "Restarting application..."
    "$MAIN_SCRIPT" restart web-app.yml > /dev/null 2>&1
    sleep 20
    
    # Verify data persists after restart
    local data_after=$(curl -s http://localhost:3000/api/data)
    assert_contains "$data_after" "Persistence test message" "Data should persist after restart"
    
    # Test volume persistence
    echo "Testing volume persistence..."
    local volume_exists=$(docker volume ls --filter "name=postgres_data" --format "{{.Name}}")
    assert_equals "postgres_data" "$volume_exists" "PostgreSQL volume should exist"
    
    local redis_volume_exists=$(docker volume ls --filter "name=redis_data" --format "{{.Name}}")
    assert_equals "redis_data" "$redis_volume_exists" "Redis volume should exist"
    
    echo "✓ Data persistence and backup test passed"
}

# Test 5: Network connectivity and isolation
test_network_connectivity_isolation() {
    echo "Testing network connectivity and isolation..."
    
    cd "$TEST_TEMP_DIR/workspace"
    
    # Install application if not already running
    if ! docker ps --filter "name=web-application" --format "{{.Names}}" | grep -q "web-application"; then
        "$MAIN_SCRIPT" install web-app.yml > /dev/null 2>&1
        sleep 30
    fi
    
    # Test internal network connectivity
    echo "Testing internal network connectivity..."
    local backend_to_db=$(docker exec web-application-backend ping -c 1 database 2>/dev/null || echo "Failed")
    assert_contains "$backend_to_db" "1 packets transmitted, 1 received" "Backend should reach database"
    
    local frontend_to_backend=$(docker exec web-application-frontend ping -c 1 backend 2>/dev/null || echo "Failed")
    assert_contains "$frontend_to_backend" "1 packets transmitted, 1 received" "Frontend should reach backend"
    
    # Test external port accessibility
    echo "Testing external port accessibility..."
    local frontend_port=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
    assert_equals "200" "$frontend_port" "Frontend should be accessible on port 8080"
    
    local backend_port=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
    assert_equals "200" "$backend_port" "Backend should be accessible on port 3000"
    
    # Test network isolation
    echo "Testing network isolation..."
    local networks=$(docker network ls --filter "name=web-application" --format "{{.Name}}")
    assert_contains "$networks" "web-application" "Application network should exist"
    
    echo "✓ Network connectivity and isolation test passed"
}

# Test 6: Complete cleanup workflow
test_complete_cleanup_workflow() {
    echo "Testing complete cleanup workflow..."
    
    cd "$TEST_TEMP_DIR/workspace"
    
    # Install application if not already running
    if ! docker ps --filter "name=web-application" --format "{{.Names}}" | grep -q "web-application"; then
        "$MAIN_SCRIPT" install web-app.yml > /dev/null 2>&1
        sleep 30
    fi
    
    # Test application cleanup
    echo "Testing application cleanup..."
    local cleanup_result=$("$MAIN_SCRIPT" cleanup web-app.yml 2>&1)
    local cleanup_exit_code=$?
    
    assert_exit_code 0 "$cleanup_exit_code" "Application cleanup should succeed"
    assert_contains "$cleanup_result" "cleaned" "Cleanup should report success"
    
    # Verify containers are removed
    local containers_after=$(docker ps -a --filter "name=web-application" --format "{{.Names}}")
    assert_equals "" "$containers_after" "All application containers should be removed"
    
    # Verify volumes are removed
    local volumes_after=$(docker volume ls --filter "name=postgres_data" --format "{{.Name}}")
    assert_equals "" "$volumes_after" "Application volumes should be removed"
    
    echo "✓ Complete cleanup workflow test passed"
}

# Main test execution
main() {
    echo "Starting complete workflow functional tests..."
    
    # Setup test environment
    setup_test
    
    # Run tests
    test_complete_deployment_workflow
    test_application_scaling_management
    test_logging_monitoring
    test_data_persistence_backup
    test_network_connectivity_isolation
    test_complete_cleanup_workflow
    
    # Cleanup
    cleanup_test
    
    echo "All complete workflow functional tests passed!"
}

# Run main function
main "$@" 