.PHONY: help setup start test lint precommit db db.stop db.reset cover clean \
       test.failed test.integration migrate rollback routes console iex

help: ## Show this help
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Setup & Run ──────────────────────────────────────────────

setup: ## Full project setup (Docker + deps + DB + assets)
	docker compose up -d --wait
	git config core.hooksPath .githooks
	mix setup

start: ## Start the Phoenix server
	mix phx.server

iex: ## Start the server inside IEx
	iex -S mix phx.server

console: ## Open an IEx console (no server)
	iex -S mix

# ── Database ─────────────────────────────────────────────────

db: ## Start database containers
	docker compose up -d --wait

db.stop: ## Stop database containers
	docker compose down

db.reset: ## Reset the development database
	mix ecto.reset

migrate: ## Run pending migrations
	mix ecto.migrate

rollback: ## Rollback the last migration
	mix ecto.rollback

# ── Testing ──────────────────────────────────────────────────

test: ## Run the test suite
	mix test

test.failed: ## Re-run previously failed tests
	mix test --failed

test.integration: ## Run integration tests (requires Docker)
	mix test --only integration

test.file: ## Run a single test file (usage: make test.file F=test/path_test.exs)
	mix test $(F)

cover: ## Run tests with coverage
	mix test --cover

# ── Quality ──────────────────────────────────────────────────

lint: ## Check formatting and run Credo
	mix format --check-formatted
	mix credo --strict

precommit: ## Run full precommit checks (compile + format + credo + test)
	mix precommit

format: ## Auto-format all files
	mix format

# ── Utilities ────────────────────────────────────────────────

routes: ## List all application routes
	mix phx.routes

clean: ## Remove build artifacts
	rm -rf _build deps
