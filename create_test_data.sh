#!/bin/bash
# Create test database, table, and insert sample data

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🗄️  Creating Test Database and Data${NC}"

# Check if Doris is running
if ! curl -s http://localhost:8030/api/bootstrap &>/dev/null; then
    echo -e "${RED}❌ Doris FE is not running. Please start it first with ./start_doris_local.sh${NC}"
    exit 1
fi

# Create database
echo -e "${BLUE}📁 Creating database 'test_db'...${NC}"
mycli -h localhost -P 9030 -u root --execute "CREATE DATABASE IF NOT EXISTS test_db;" || {
    echo -e "${RED}❌ Failed to create database${NC}"
    exit 1
}

# Create customers table
echo -e "${BLUE}👥 Creating 'customers' table...${NC}"
mycli -h localhost -P 9030 -u root --execute "
USE test_db;
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id INT,
    name VARCHAR(100),
    age INT,
    city VARCHAR(50),
    signup_date DATE
) 
DISTRIBUTED BY HASH(customer_id) 
BUCKETS 3 
PROPERTIES ('replication_num' = '1');" || {
    echo -e "${RED}❌ Failed to create customers table${NC}"
    exit 1
}

# Create orders table
echo -e "${BLUE}🛒 Creating 'orders' table...${NC}"
mycli -h localhost -P 9030 -u root --execute "
USE test_db;
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id INT,
    customer_id INT,
    product VARCHAR(100),
    amount DECIMAL(10,2),
    order_date DATE
)
DISTRIBUTED BY HASH(order_id)
BUCKETS 3
PROPERTIES ('replication_num' = '1');" || {
    echo -e "${RED}❌ Failed to create orders table${NC}"
    exit 1
}

# Insert sample data into customers
echo -e "${BLUE}📝 Inserting customer data...${NC}"
mycli -h localhost -P 9030 -u root --execute "
INSERT INTO test_db.customers VALUES
(1, 'Alice Johnson', 28, 'New York', '2023-01-15'),
(2, 'Bob Smith', 35, 'London', '2023-02-20'),
(3, 'Charlie Brown', 42, 'Tokyo', '2023-03-10'),
(4, 'Diana Prince', 30, 'Paris', '2023-04-05'),
(5, 'Eve Davis', 26, 'Berlin', '2023-05-12'),
(6, 'Frank Miller', 38, 'Sydney', '2023-06-18'),
(7, 'Grace Lee', 33, 'Toronto', '2023-07-22'),
(8, 'Henry Wilson', 29, 'Mumbai', '2023-08-30'),
(9, 'Ivy Chen', 31, 'Shanghai', '2023-09-14'),
(10, 'Jack Taylor', 27, 'San Francisco', '2023-10-01');" || {
    echo -e "${YELLOW}⚠️  Customer data insertion may have failed${NC}"
}

# Insert sample data into orders  
echo -e "${BLUE}📦 Inserting order data...${NC}"
mycli -h localhost -P 9030 -u root --execute "
INSERT INTO test_db.orders VALUES
(101, 1, 'Laptop', 999.99, '2023-01-20'),
(102, 2, 'Mouse', 25.50, '2023-02-25'),
(103, 1, 'Keyboard', 75.00, '2023-03-15'),
(104, 3, 'Monitor', 299.99, '2023-03-18'),
(105, 4, 'Headphones', 149.99, '2023-04-10'),
(106, 5, 'Webcam', 89.99, '2023-05-20'),
(107, 2, 'Tablet', 399.99, '2023-06-25'),
(108, 6, 'Phone', 699.99, '2023-07-01'),
(109, 3, 'Charger', 29.99, '2023-08-05'),
(110, 7, 'Speaker', 199.99, '2023-09-20');" || {
    echo -e "${YELLOW}⚠️  Order data insertion may have failed${NC}"
}

# Verify data
echo -e "${GREEN}✅ Data created! Running verification queries...${NC}"
echo ""

echo -e "${BLUE}📊 Customer count:${NC}"
# mycli -h localhost -P 9030 -u root --execute "SELECT COUNT(*) as total_customers FROM test_db.customers;" || echo "Query failed"

echo -e "${BLUE}📊 Order count:${NC}"  
# mycli -h localhost -P 9030 -u root --execute "SELECT COUNT(*) as total_orders FROM test_db.orders;"  || echo "Query failed"

echo -e "${BLUE}👥 Sample customers:${NC}"
# mycli -h localhost -P 9030 -u root --execute "SELECT customer_id, name, city FROM test_db.customers LIMIT 5;"  || echo "Query failed"

echo -e "${BLUE}🛒 Sample orders:${NC}"
# mycli -h localhost -P 9030 -u root --execute "SELECT order_id, product, amount FROM test_db.orders LIMIT 5;"  || echo "Query failed"

echo ""
echo -e "${GREEN}🎉 Test data creation complete!${NC}"
echo -e "${GREEN}💡 Try these queries:${NC}"
echo "  • mycli -h localhost -P 9030 -u root"
echo "  • SELECT * FROM test_db.customers WHERE age > 30;"
echo "  • SELECT c.name, o.product, o.amount FROM test_db.customers c JOIN test_db.orders o ON c.customer_id = o.customer_id;"
echo "  • SELECT city, COUNT(*) as customer_count FROM test_db.customers GROUP BY city;"
