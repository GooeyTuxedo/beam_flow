#!/bin/sh
# Reset the test database

# Set environment variables to ensure we're targeting the test environment
export MIX_ENV=test

# Drop and recreate the test database
echo "Dropping test database..."
mix ecto.drop
echo "Creating test database..."
mix ecto.create
echo "Running migrations on test database..."
mix ecto.migrate
echo "Test database has been reset and migrated."