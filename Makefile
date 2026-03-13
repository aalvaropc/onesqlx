.PHONY: help setup start test lint precommit db db.stop db.reset cover clean

help: ## Show this help
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Full project setup (Docker + deps + DB + assets)
	docker compose up -d --wait
	git config core.hooksPath .githooks
	mix setup

start: ## Start the Phoenix server
	mix phx.server

test: ## Run the test suite
	mix test

test.integration: ## Run integration tests (requires Docker)
	mix test --only integration

lint: ## Check formatting and run Credo
	mix format --check-formatted
	mix credo --strict

precommit: ## Run full precommit checks (compile + format + credo + test)
	mix precommit

db: ## Start database containers
	docker compose up -d --wait

db.stop: ## Stop database containers
	docker compose down

db.reset: ## Reset the development database
	mix ecto.reset

cover: ## Run tests with coverage
	mix test --cover

clean: ## Remove build artifacts
	rm -rf _build deps
