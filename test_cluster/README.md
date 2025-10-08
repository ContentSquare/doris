# Apache Doris v3 Decoupled Compute and Storage Test Cluster

This docker-compose setup provides a complete Apache Doris v3 cluster running in decoupled compute and storage mode with all required services.

## Architecture Components

### Infrastructure Services
- **FoundationDB**: Distributed metadata storage
- **MinIO**: S3-compatible object storage for data

### Doris Cloud Services  
- **MetaService**: Manages metadata and cluster coordination
- **Recycler**: Handles garbage collection and storage cleanup

### Doris Compute Services
- **Frontend (FE) Master**: Query coordination and metadata management
- **Frontend (FE) Follower**: High availability and load distribution  
- **Backend (BE) 1-3**: Stateless compute nodes

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- At least 8GB RAM available
- Ports 8030-8042, 9000-9001, 9030-9031, 9060-9062 available

### 1. Choose Your Setup

**Option A: Simple Setup (Recommended for development)**
```bash
cd test_cluster
docker-compose -f docker-compose-simple.yml up -d
```

**Option B: Hybrid Setup (Custom build + MinIO storage)**
```bash
cd test_cluster
docker-compose -f docker-compose-hybrid.yml up -d
```

**Option C: Full Decoupled (x86_64 only - requires FoundationDB)**
```bash
cd test_cluster
docker-compose -f docker-compose-decoupled.yml up -d
```

### 2. Check Service Health
```bash
# Check all services are running
docker-compose -f docker-compose-decoupled.yml ps

# Check FoundationDB status
docker exec doris-foundationdb fdbcli --exec "status"

# Check MinIO access
curl http://localhost:9001  # MinIO Console

# Check MetaService
curl "http://localhost:5000/MetaService/http/get_cluster?token=greedisgood9999"

# Check Frontend
curl http://localhost:8030/api/bootstrap
```

### 3. Connect to Doris
```bash
# Using MySQL client
mysql -h 127.0.0.1 -P 9030 -u root

# Or using docker
docker run -it --rm --network test_cluster_doris_cloud_net mysql:8.0 \
  mysql -h fe-master -P 9030 -u root
```

### 4. Initialize the Cluster
```sql
-- Add backend nodes
ALTER SYSTEM ADD BACKEND "be-1:9050";
ALTER SYSTEM ADD BACKEND "be-2:9050"; 
ALTER SYSTEM ADD BACKEND "be-3:9050";

-- Check cluster status
SHOW BACKENDS;
SHOW FRONTENDS;

-- Create a test database and table
CREATE DATABASE test_db;
USE test_db;

CREATE TABLE test_table (
    id INT,
    name VARCHAR(100),
    created_time DATETIME
) DISTRIBUTED BY HASH(id) BUCKETS 3;

-- Insert test data
INSERT INTO test_table VALUES 
(1, 'Alice', '2024-01-01 10:00:00'),
(2, 'Bob', '2024-01-01 11:00:00'),
(3, 'Charlie', '2024-01-01 12:00:00');

-- Query data
SELECT * FROM test_table;
```

## Service Endpoints

| Service | Endpoint | Purpose |
|---------|----------|---------|
| FE Master Web UI | http://localhost:8030 | Query interface and monitoring |
| FE Follower Web UI | http://localhost:8031 | Secondary query interface |
| BE-1 Web UI | http://localhost:8040 | Backend monitoring |
| BE-2 Web UI | http://localhost:8041 | Backend monitoring |
| BE-3 Web UI | http://localhost:8042 | Backend monitoring |
| MinIO Console | http://localhost:9001 | Object storage management |
| MetaService API | http://localhost:5000 | Metadata service |
| MySQL Protocol | localhost:9030 | SQL queries |

### Default Credentials
- **MinIO**: doris-admin / doris-password-123
- **Doris**: root / (no password)
- **MetaService Token**: greedisgood9999

## Key Features of Decoupled Mode

### ✅ **Stateless Compute**
- BE nodes store no persistent data
- Easy horizontal scaling
- Fast recovery and replacement

### ✅ **Shared Storage** 
- All data in MinIO/S3
- Automatic data durability
- Cross-AZ availability

### ✅ **Elastic Scaling**
- Add/remove BEs without data migration
- Independent compute/storage scaling
- Cost optimization

### ✅ **Cloud Native**
- Container-friendly architecture
- Kubernetes ready
- Multi-cloud support

## Monitoring and Debugging

### View Logs
```bash
# MetaService logs
docker logs doris-meta-service

# Recycler logs  
docker logs doris-recycler

# Frontend logs
docker logs doris-fe-master

# Backend logs
docker logs doris-be-1
```

### Check Storage
```bash
# MinIO browser: http://localhost:9001
# Login: doris-admin / doris-password-123

# List S3 buckets
docker exec doris-minio mc ls minio/

# Check FoundationDB status
docker exec doris-foundationdb fdbcli --exec "status"
```

### Performance Tuning
- Adjust BE memory limits in docker-compose.yml
- Modify cache sizes in be-cloud.conf
- Scale BE instances for more compute power
- Use SSD storage for better performance

## Cleanup

```bash
# Stop and remove all containers
docker-compose -f docker-compose-decoupled.yml down

# Remove volumes (WARNING: deletes all data)
docker-compose -f docker-compose-decoupled.yml down -v
```

## Troubleshooting

### Common Issues

1. **Services won't start**: Check port conflicts and available memory
2. **FoundationDB fails**: Ensure no other FDB instances running on port 4500  
3. **MinIO access denied**: Verify credentials and bucket permissions
4. **MetaService can't connect**: Check FoundationDB health first
5. **BE nodes not joining**: Verify network connectivity and FE health

### Health Checks
All services have built-in health checks. Use `docker-compose ps` to see service health status.

## Production Considerations

This setup is for development and testing. For production:

- Use external FoundationDB cluster (3+ nodes)
- Use production S3 or distributed storage
- Configure proper resource limits
- Set up monitoring and alerting
- Use secrets management for credentials
- Configure SSL/TLS encryption
- Set up backup and disaster recovery