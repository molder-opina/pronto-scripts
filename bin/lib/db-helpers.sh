#!/bin/bash

# Database helper functions for pronto-scripts

check_column_exists() {
    local table_name="$1"
    local column_name="$2"
    
    psql -t -c "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = current_schema() AND TABLE_NAME = '${table_name}' AND COLUMN_NAME = '${column_name}';" | grep -q "^[[:space:]]*1[[:space:]]*$"
}

execute_sql_file() {
    local sql_file="$1"
    
    if [ ! -f "$sql_file" ]; then
        echo "Error: SQL file not found: $sql_file" >&2
        return 1
    fi
    
    psql -f "$sql_file"
}