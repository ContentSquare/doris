#!/bin/bash
# Start Doris FE and BE locally with custom builds

# set -e removed to prevent silent failures

# Configuration
DORIS_HOME="/Users/ryad.zenine/workspace/doris"
FE_HOME="${DORIS_HOME}/output/fe"
BE_HOME="${DORIS_HOME}/output/be"
JAVA_HOME="/opt/homebrew/Cellar/openjdk@17/17.0.16/libexec/openjdk.jdk/Contents/Home"

# Colors for output
GREEN='\033[0;32m'  
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Doris Local Cluster${NC}"

# Kill existing processes
echo -e "${YELLOW}🔪 Killing existing Doris processes...${NC}"
pkill -f "DorisMain" 2>/dev/null || echo "No FE processes to kill"
pkill -f "doris_be" 2>/dev/null || echo "No BE processes to kill"

# Also kill by port if needed
FE_PID=$(lsof -ti:9030 2>/dev/null)
BE_PID=$(lsof -ti:8040 2>/dev/null)
[ -n "$FE_PID" ] && kill -9 $FE_PID 2>/dev/null && echo "Killed FE process on port 9030"
[ -n "$BE_PID" ] && kill -9 $BE_PID 2>/dev/null && echo "Killed BE process on port 8040"

# Wait for processes to fully terminate
sleep 2

# Set environment
export JAVA_HOME="${JAVA_HOME}"
export DORIS_HOME

# Start FE
echo -e "${GREEN}📊 Starting Frontend (FE)...${NC}"
cd "${FE_HOME}"
DORIS_HOME="${FE_HOME}" ./bin/start_fe.sh --daemon

# Health check for FE
echo -e "${YELLOW}🏥 Waiting for FE to be ready...${NC}"
FE_READY=false
for i in {1..30}; do
    if curl -s http://localhost:8030/api/bootstrap &>/dev/null; then
        echo -e "${GREEN}✅ FE is ready!${NC}"
        FE_READY=true
        break
    else
        echo -n "."
        sleep 2
    fi
done

if [ "$FE_READY" = false ]; then
    echo -e "${RED}❌ FE failed to start after 60 seconds${NC}"
    exit 1
fi

# Start BE  
echo -e "${GREEN}⚙️  Starting Backend (BE)...${NC}"
cd "${BE_HOME}"
ulimit -n 65536
DORIS_HOME="${BE_HOME}" ./bin/start_be.sh --daemon  &

# Health check for BE
echo -e "${YELLOW}🏥 Waiting for BE to be ready...${NC}"
BE_READY=false
for i in {1..20}; do
    if curl -s http://localhost:8040/api/health | grep -q '"status": "OK"'; then
        echo -e "${GREEN}✅ BE is ready!${NC}"
        BE_READY=true
        break
    else
        echo -n "."
        sleep 3
    fi
done

if [ "$BE_READY" = false ]; then
    echo -e "${RED}❌ BE failed to start after 60 seconds${NC}"
    exit 1
fi

# Register BE with FE
echo -e "${GREEN}🔗 Registering BE with FE...${NC}"
LOCAL_IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
echo "Using local IP: ${LOCAL_IP}"

# Wait for MySQL service to be ready
echo -e "${YELLOW}🔍 Waiting for MySQL service to be ready...${NC}"
MYSQL_READY=false
for i in {1..10}; do
    if curl -s http://localhost:8030/api/health | grep -q '"code":0'; then
        echo -e "${GREEN}✅ MySQL service is ready!${NC}"
        MYSQL_READY=true
        break
    else
        echo -n "."
        sleep 2
    fi
done

if [ "$MYSQL_READY" = false ]; then
    echo -e "${RED}❌ MySQL service not ready after 20 seconds${NC}"
    exit 1
fi

# Check if BE is already registered, if not register it
echo -e "${GREEN}🔍 Checking BE registration status...${NC}"
EXISTING_BE=$(mycli -h localhost -P 9030 -u root --execute "SHOW BACKENDS;" 2>/dev/null | grep "${LOCAL_IP}" || echo "")

if [ -n "$EXISTING_BE" ]; then
    echo -e "${YELLOW}📍 BE ${LOCAL_IP}:9050 already registered${NC}"
    BE_REGISTERED=true
else
    echo -e "${GREEN}🔗 Registering new BE...${NC}"
    # Try to register BE (may take a few attempts)
    BE_REGISTERED=false
    for i in {1..5}; do
        if mycli -h localhost -P 9030 -u root --execute "ALTER SYSTEM ADD BACKEND '${LOCAL_IP}:9050';" 2>/dev/null; then
            echo -e "${GREEN}✅ BE registration command sent${NC}"
            BE_REGISTERED=true
            break
        else
            echo -e "${YELLOW}⏳ Attempt $i: Waiting for MySQL connection...${NC}"
            sleep 5
        fi
    done

    if [ "$BE_REGISTERED" = false ]; then
        echo -e "${RED}❌ Failed to register BE with FE${NC}"
        exit 1
    fi
fi

# Verify BE registration and wait for it to be alive
echo -e "${YELLOW}🔍 Verifying BE registration...${NC}"
BE_ALIVE=false
for i in {1..10}; do
    if mycli -h localhost -P 9030 -u root --execute "SHOW BACKENDS;" 2>/dev/null | grep -q "true.*${LOCAL_IP}"; then
        echo -e "${GREEN}✅ BE is alive and registered!${NC}"
        BE_ALIVE=true
        break
    else
        echo -n "."
        sleep 3
    fi
done

if [ "$BE_ALIVE" = false ]; then
    echo -e "${YELLOW}⚠️  BE registered but may not be fully alive yet${NC}"
    echo -e "${YELLOW}   Check status with: mycli -h localhost -P 9030 -u root --execute \"SHOW BACKENDS;\"${NC}"
fi

# Final cluster status check
echo -e "${GREEN}📋 Final cluster status check...${NC}"

# Test basic connectivity
CLUSTER_HEALTHY=true

# Check FE health
if ! curl -s http://localhost:8030/api/bootstrap &>/dev/null; then
    echo -e "${RED}❌ FE health check failed${NC}"
    CLUSTER_HEALTHY=false
fi

# Check BE health  
if ! curl -s http://localhost:8040/api/health | grep -q '"status": "OK"'; then
    echo -e "${RED}❌ BE health check failed${NC}"
    CLUSTER_HEALTHY=false
fi

# Check MySQL connectivity (with better error handling)
if ! curl -s http://localhost:8030/api/health | grep -q '"code":0'; then
    echo -e "${RED}❌ MySQL service health check failed${NC}"
    CLUSTER_HEALTHY=false
elif ! timeout 5 mycli -h localhost -P 9030 -u root --execute "SELECT 1;" &>/dev/null; then
    echo -e "${YELLOW}⚠️  MySQL protocol connection slow but service is healthy${NC}"
fi

if [ "$CLUSTER_HEALTHY" = true ]; then
    echo -e "${GREEN}🎉 Doris cluster is running successfully!${NC}"
    echo ""
    echo -e "${GREEN}📍 Access points:${NC}"
    echo "  • FE Web UI: http://localhost:8030"
    echo "  • BE Web UI: http://localhost:8040" 
    echo "  • MySQL Protocol: mysql -h localhost -P 9030 -u root"
    echo "  • Or use: mycli -h localhost -P 9030 -u root"
    echo ""
    echo -e "${GREEN}🔍 Quick status:${NC}"
    mycli -h localhost -P 9030 -u root --execute "SHOW BACKENDS\\G" 2>/dev/null | grep -E "(Host|Alive|Version)" || echo "  Backend status query failed"
    echo ""
    echo -e "${GREEN}💡 Next step: Run ./create_test_data.sh to create sample data${NC}"
else
    echo -e "${RED}❌ Cluster startup has issues. Check logs:${NC}"
    echo "  • FE logs: ${FE_HOME}/log/"
    echo "  • BE logs: ${BE_HOME}/log/"
    echo "  • Try: mycli -h localhost -P 9030 -u root --execute \"SHOW BACKENDS;\""
fi

# Attach LLDB to BE process for debugging
echo ""
echo -e "${GREEN}🐛 Attaching LLDB to BE process for debugging...${NC}"
BE_PID=$(pgrep -f "doris_be" | head -1)
if [ -n "$BE_PID" ]; then
    echo -e "${GREEN}📍 Found BE process with PID: ${BE_PID}${NC}"
    echo -e "${YELLOW}🔧 Starting LLDB... (type 'continue' to let BE run, 'bt' for backtrace on crash)${NC}"
    echo -e "${YELLOW}   LLDB commands: 'c' (continue), 'bt' (backtrace), 'q' (quit)${NC}"
    sleep 2
    lldb -p ${BE_PID}
else
    echo -e "${RED}❌ Could not find BE process to attach debugger${NC}"
fi
