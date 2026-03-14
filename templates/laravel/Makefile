# ============================================================
# Makefile — copy and adapt per project
# Usage: make <target>   or   make help
# ============================================================

APP_NAME  ?= app
NAMESPACE ?= default

.PHONY: help up down fresh build logs shell \
        migrate seed tinker \
        encrypt decrypt \
        k8s-status k8s-logs k8s-shell k8s-apply k8s-delete

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Local development ──────────────────────────────────────

up: ## Start all containers in background
	docker compose up -d

down: ## Stop all containers
	docker compose down

fresh: ## Full reset: stop + delete volumes + start
	docker compose down -v
	docker compose up -d

build: ## Rebuild images (use after Dockerfile changes)
	docker compose build

logs: ## Tail logs — usage: make logs s=app
	docker compose logs -f $(s)

shell: ## Shell inside a container — usage: make shell s=app
	docker compose exec $(s) sh

# ── Laravel shortcuts ──────────────────────────────────────

migrate: ## Run php artisan migrate
	docker compose exec app php artisan migrate

seed: ## Run php artisan db:seed
	docker compose exec app php artisan db:seed

tinker: ## Open Laravel Tinker
	docker compose exec app php artisan tinker

# ── Secrets ────────────────────────────────────────────────

encrypt: ## Encrypt .env → .env.encrypted — usage: make encrypt ENCRYPT_KEY=xxx
	@[ -n "$(ENCRYPT_KEY)" ] || (echo "Error: ENCRYPT_KEY not set. Run: make encrypt ENCRYPT_KEY=yourkey" && exit 1)
	ENCRYPT_KEY=$(ENCRYPT_KEY) ./envcrypt.sh encrypt

decrypt: ## Decrypt .env.encrypted → .env — usage: make decrypt ENCRYPT_KEY=xxx
	@[ -n "$(ENCRYPT_KEY)" ] || (echo "Error: ENCRYPT_KEY not set." && exit 1)
	ENCRYPT_KEY=$(ENCRYPT_KEY) ./envcrypt.sh decrypt

# ── Kubernetes ─────────────────────────────────────────────

k8s-status: ## Show pods, deployments and services in cluster
	@echo "\n=== Deployments ==="
	@kubectl get deployments -n $(NAMESPACE) -l app=$(APP_NAME)
	@echo "\n=== Pods ==="
	@kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME)
	@echo "\n=== Services ==="
	@kubectl get svc -n $(NAMESPACE) -l app=$(APP_NAME)

k8s-logs: ## Tail all pod logs — usage: make k8s-logs
	kubectl logs -f -l app=$(APP_NAME) -n $(NAMESPACE) --all-containers

k8s-shell: ## Shell inside the running pod
	kubectl exec -it \
		$(shell kubectl get pod -l app=$(APP_NAME),component=app -n $(NAMESPACE) -o name | head -1) \
		-n $(NAMESPACE) -c octane -- sh

k8s-apply: ## Apply all manifests in app/k8s/
	kubectl apply -f app/k8s/ -n $(NAMESPACE)

k8s-delete: ## Delete all resources in app/k8s/
	kubectl delete -f app/k8s/ -n $(NAMESPACE)