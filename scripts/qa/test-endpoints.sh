#!/bin/bash
# Test script to reproduce the reported errors

echo "=========================================="
echo "Testing Pronto Application Endpoints"
echo "=========================================="
echo ""

# Get auth token (assuming admin login)
echo "1. Testing Analytics KPIs endpoint..."
curl -s -X GET "http://localhost:6081/api/analytics/kpis" \
  -H "Content-Type: application/json" \
  -b cookies.txt | jq -r '.message // .error // "Success"'
echo ""

echo "2. Testing Create Area endpoint..."
curl -s -X POST "http://localhost:6081/api/areas" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"name":"Jardín","prefix":"J","description":"Área al aire libre","color":"#00ff00"}' | jq -r '.message // .error // "Success"'
echo ""

echo "3. Testing Create Table endpoint..."
curl -s -X POST "http://localhost:6081/api/tables" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"table_number":"J-M01","zone":"Jardín","capacity":4,"shape":"round"}' | jq -r '.message // .error // "Success"'
echo ""

echo "4. Testing Update Menu Item Price endpoint..."
curl -s -X PUT "http://localhost:6081/api/menu-items/1" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"price":15.99}' | jq -r '.message // .error // "Success"'
echo ""

echo "=========================================="
echo "Checking Docker logs for errors..."
echo "=========================================="
docker logs pronto-employee --tail 50 | grep -i "error\|exception" || echo "No errors found in recent logs"
