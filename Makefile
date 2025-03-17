.PHONY: help setup build start stop restart shell logs \
	deps compile clean format lint test test.watch \
	db.setup db.reset db.migrate db.rollback \
	routes release

# Define colors
YELLOW := \033[0;33m
GREEN := \033[0;32m
NC := \033[0m

help: ## Show this help
	@echo "BeamFlow CMS Development Commands"
	@echo "----------------------------------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

## Docker commands
setup: ## Initialize the project (first-time setup)
	@echo "$(GREEN)Setting up BeamFlow CMS project...$(NC)"
	@mkdir -p scripts
	@chmod +x scripts/init-test-db.sh 2>/dev/null || true
	@chmod +x .husky/pre-commit 2>/dev/null || true
	@chmod +x .husky/commit-msg 2>/dev/null || true
	@npm install
	@docker compose build
	@docker compose run --rm app mix deps.get
	@docker compose run --rm app mix ecto.setup
	@docker compose run --rm app bash -c "cd assets && npm install"
	@echo "$(GREEN)Setup complete. Run 'make start' to start the application.$(NC)"

build: ## Rebuild the Docker containers
	@echo "$(GREEN)Building Docker containers...$(NC)"
	@docker compose build

start: ## Start the application
	@echo "$(GREEN)Starting BeamFlow CMS...$(NC)"
	@docker compose up -d
	@echo "$(GREEN)Application is running at http://localhost:4000$(NC)"

stop: ## Stop the application
	@echo "$(GREEN)Stopping BeamFlow CMS...$(NC)"
	@docker compose down

restart: ## Restart the application
	@make stop
	@make start

shell: ## Connect to the application container shell
	@docker compose exec app bash

logs: ## View application logs
	@docker compose logs -f app

## Development commands
deps: ## Get and compile dependencies
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@docker compose exec app mix deps.get
	@docker compose exec app mix deps.compile

compile: ## Compile the application
	@echo "$(GREEN)Compiling application...$(NC)"
	@docker compose exec app mix compile

clean: ## Clean compiled artifacts
	@echo "$(GREEN)Cleaning compiled artifacts...$(NC)"
	@docker compose exec app mix clean

format: ## Format code
	@echo "$(GREEN)Formatting code...$(NC)"
	@docker compose exec app mix format

lint: ## Run code linting
	@echo "$(GREEN)Running code linting...$(NC)"
	@docker compose exec app mix credo --strict

test: ## Run tests
	@echo "$(GREEN)Running tests...$(NC)"
	@docker compose exec app mix test

test.watch: ## Run tests in watch mode
	@echo "$(GREEN)Running tests in watch mode...$(NC)"
	@docker compose exec app mix test.watch

coverage: ## Generate test coverage report
	@echo "$(GREEN)Generating test coverage report...$(NC)"
	@docker compose exec app mix coveralls.html
	@echo "$(GREEN)Coverage report generated in cover/excoveralls.html$(NC)"

## Database commands
db.setup: ## Set up the database
	@echo "$(GREEN)Setting up database...$(NC)"
	@docker compose exec app mix ecto.setup

db.reset: ## Reset the database
	@echo "$(GREEN)Resetting database...$(NC)"
	@docker compose exec app mix ecto.reset

db.migrate: ## Run database migrations
	@echo "$(GREEN)Running database migrations...$(NC)"
	@docker compose exec app mix ecto.migrate

db.rollback: ## Rollback the last database migration
	@echo "$(GREEN)Rolling back last migration...$(NC)"
	@docker compose exec app mix ecto.rollback

## Phoenix commands
routes: ## List all routes
	@echo "$(GREEN)Listing routes...$(NC)"
	@docker compose exec app mix phx.routes

gen.context: ## Generate a new context (e.g. make gen.context name=accounts schema=user fields="email:string:unique name:string")
	@echo "$(GREEN)Generating new context...$(NC)"
	@docker compose exec app mix phx.gen.context $(name) $(schema) $(fields)

gen.schema: ## Generate a new schema (e.g. make gen.schema name=accounts schema=user fields="email:string:unique name:string")
	@echo "$(GREEN)Generating new schema...$(NC)"
	@docker compose exec app mix phx.gen.schema $(name) $(schema) $(fields)

gen.live: ## Generate a LiveView CRUD interface (e.g. make gen.live name=admin/post schema=content/post fields="title:string slug:string:unique content:text status:enum:draft:published")
	@echo "$(GREEN)Generating LiveView CRUD...$(NC)"
	@docker compose exec app mix phx.gen.live $(name) $(schema) $(fields)

gen.auth: ## Generate authentication system
	@echo "$(GREEN)Generating authentication system...$(NC)"
	@docker compose exec app mix phx.gen.auth Accounts User users

release: ## Build a release
	@echo "$(GREEN)Building release...$(NC)"
	@docker compose exec -e MIX_ENV=prod app mix release

## NPM Commands
npm.install: ## Install NPM dependencies
	@echo "$(GREEN)Installing NPM dependencies...$(NC)"
	@docker compose exec app bash -c "cd assets && npm install"

npm.build: ## Build assets
	@echo "$(GREEN)Building assets...$(NC)"
	@docker compose exec app bash -c "cd assets && npm run deploy"

## Git Hooks
hooks.setup: ## Set up git hooks
	@echo "$(GREEN)Setting up git hooks...$(NC)"
	@npm install
	@npm run prepare
	@chmod +x .husky/pre-commit
	@chmod +x .husky/commit-msg
	@chmod +x scripts/elixir-pre-commit.sh
	@echo "$(GREEN)Hooks installed successfully. Make sure Elixir dependencies are installed with 'make deps'$(NC)"