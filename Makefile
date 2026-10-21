# Dev-stack lokal. Butuh Docker Compose v2, openssl, curl.
# BACKEND_DIR: checkout lumbung-backend-service (branch yang ingin dijalankan), default saudara repo ini.
BACKEND_DIR ?= $(abspath $(CURDIR)/../lumbung-backend-service)
DEV_DIR     := $(CURDIR)/deploy/dev
COMPOSE      = BACKEND_PORT=$(BACKEND_PORT) BACKEND_DIR=$(BACKEND_DIR) DEV_DIR=$(DEV_DIR) docker compose --env-file $(DEV_DIR)/.env -f $(DEV_DIR)/compose.yaml
BACKEND_PORT ?= 18480

.PHONY: dev-up dev-down dev-reset dev-logs dev-seed

dev-up: ## bangun dan nyalakan backend + Postgres (menunggu sehat)
	@$(DEV_DIR)/gen-env.sh
	$(COMPOSE) up -d --build --wait

dev-down: ## matikan (data DB dipertahankan)
	$(COMPOSE) down

dev-reset: ## matikan dan HAPUS data DB dev
	$(COMPOSE) down -v

dev-logs:
	$(COMPOSE) logs -f backend

dev-seed: ## semai akun uji (butuh contract/seed.py di backend dan uvx); HANYA DB dev
	@test -f $(BACKEND_DIR)/contract/seed.py || { echo "contract/seed.py tidak ada di $(BACKEND_DIR) (branch uji kontrak backend)"; exit 2; }
	@set -a; . $(DEV_DIR)/.env; set +a; \
	  uvx --with argon2-cffi python $(BACKEND_DIR)/contract/seed.py "postgres://lumbung_app:$$POSTGRES_PASSWORD@127.0.0.1:$${DB_PORT:-15532}/lumbung"
