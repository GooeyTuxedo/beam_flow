.PHONY: help setup start stop restart build shell logs \
	deps compile clean format lint test test.watch \
	db.setup db.reset db.migrate db.rollback \
	routes gen.context gen.schema gen.live gen.auth release

# Define colors
YELLOW := \033[0;33m
GREEN := \033[0;32m
NC := \033[0m

# Set the Phoenix version
PHOENIX_VERSION := 1.7.20

help: ## Show this help
	@echo "BeamFlow CMS Development Commands"
	@echo "----------------------------------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

setup: ## Set up the project (first time)
	@echo "$(GREEN)Setting up BeamFlow CMS project...$(NC)"
	@mkdir -p scripts
	@chmod +x scripts/init-test-db.sh 2>/dev/null || true
	@echo "$(GREEN)Setup complete. Run 'make build' to build the Docker image.$(NC)"

build: ## Build the Docker image
	@echo "$(GREEN)Building Docker image...$(NC)"
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
	@docker compose exec app sh

logs: ## View application logs
	@docker compose logs -f

# Development commands
deps: ## Get and compile dependencies
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@docker compose exec app mix deps.get

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

# Database commands
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

# Phoenix commands
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

# Project initialization
init: ## Initialize a fresh Phoenix project
	@echo "$(GREEN)Initializing fresh Phoenix project...$(NC)"
	@docker compose run --rm app mix local.hex --force
	@docker compose run --rm app mix archive.install hex phx_new $(PHOENIX_VERSION) --force
	@docker compose run --rm app mix phx.new . --app beam_flow --module BeamFlow --database postgres
	@docker compose run --rm app mix deps.get
	@mkdir -p lib/beam_flow/{accounts,content,engagement,site,utils}
	@mkdir -p lib/beam_flow_web/live/{admin,public}
	@mkdir -p lib/beam_flow_web/components
	@echo "$(GREEN)Phoenix $(PHOENIX_VERSION) project initialized.$(NC)"
	@echo "$(GREEN)Run 'make db.setup' to set up the database.$(NC)"
	@echo "$(GREEN)Run 'make start' to start the application.$(NC)"

# Production build
release: ## Build a production release
	@echo "$(GREEN)Building production release...$(NC)"
	@docker compose exec -e MIX_ENV=prod app mix phx.gen.release
	@docker compose exec -e MIX_ENV=prod app mix release
	@echo "$(GREEN)Release built. Find it in _build/prod/rel/beam_flow/$(NC)"