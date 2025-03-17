#!/bin/bash
set -e

# Ensure we're in the project root
cd "$(git rev-parse --show-toplevel)"

# Verify dependencies are installed
if [ ! -d "deps/credo" ]; then
  echo "Installing Elixir dependencies..."
  mix deps.get
fi

# Get staged Elixir files
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ex|exs)$')

if [ -n "$files" ]; then
  echo "Running formatting check on staged Elixir files..."
  echo "$files" | xargs mix format

  echo "Running Credo static code analysis..."
  # Set MIX_ENV explicitly and pass only the staged files to credo
  MIX_ENV=dev mix credo --strict $files || {
    echo "Credo found issues. Please fix them before committing."
    exit 1
  }
fi

# Stage formatted files
echo "$files" | xargs git add