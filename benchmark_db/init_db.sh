#!/bin/bash
# Initialize GuacaMol Benchmark Database

set -e

DB_PATH="/home/ubuntu/mangodb/benchmark_db/guacamol_benchmarks.db"
SCHEMA_PATH="/home/ubuntu/mangodb/benchmark_db/schema.sql"
DATA_PATH="/home/ubuntu/mangodb/benchmark_db/populate_table3.sql"

echo "Initializing GuacaMol Benchmark Database..."

# Remove existing database if present
if [ -f "$DB_PATH" ]; then
    echo "Removing existing database..."
    rm "$DB_PATH"
fi

# Create database with schema
echo "Creating schema..."
sqlite3 "$DB_PATH" < "$SCHEMA_PATH"

# Populate with Table 3 data
echo "Populating with Table 3 data..."
sqlite3 "$DB_PATH" < "$DATA_PATH"

# Verify database
echo ""
echo "Database initialized successfully!"
echo "Location: $DB_PATH"
echo ""
echo "Verification:"
sqlite3 "$DB_PATH" "SELECT COUNT(*) as num_benchmarks FROM benchmarks;" ".mode box"
sqlite3 "$DB_PATH" "SELECT COUNT(*) as num_objectives FROM scoring_functions;" ".mode box"
echo ""
echo "Benchmark summary:"
sqlite3 "$DB_PATH" "SELECT * FROM benchmark_summary ORDER BY category, benchmark_name;" ".mode box"
