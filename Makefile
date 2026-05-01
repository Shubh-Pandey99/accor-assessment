.PHONY: help init plan apply destroy deploy deploy-staging validate scan test test-smoke lint clean docs-pdf

SHELL := /bin/bash
AWS_REGION ?= ap-southeast-1
ENVIRONMENT ?= production
CLUSTER_NAME ?= redemption-prod
TF_DIR := terraform
K8S_DIR := kubernetes

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

# terraform
init: ## init terraform
	cd $(TF_DIR) && terraform init

plan: ## plan changes
	cd $(TF_DIR) && terraform plan -var-file=environments/$(ENVIRONMENT)/terraform.tfvars -out=tfplan

apply: ## apply changes
	cd $(TF_DIR) && terraform apply tfplan

destroy: ## destroy everything (asks for confirmation)
	cd $(TF_DIR) && terraform destroy -var-file=environments/$(ENVIRONMENT)/terraform.tfvars

validate: ## validate terraform + fmt check
	cd $(TF_DIR) && terraform fmt -check -recursive && terraform validate

lint: ## check terraform formatting
	terraform fmt -check -recursive terraform/
	@echo "Terraform formatting OK"

# kubernetes
kubeconfig: ## configure kubectl
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)

deploy: ## deploy to production
	kustomize build $(K8S_DIR)/overlays/production | kubectl apply -f -
	kubectl rollout status deployment/redemption-service -n redemption --timeout=300s

deploy-staging: ## deploy to staging
	kustomize build $(K8S_DIR)/overlays/staging | kubectl apply -f -
	kubectl rollout status deployment/redemption-service -n redemption --timeout=300s

rollback: ## rollback last deployment
	kubectl rollout undo deployment/redemption-service -n redemption

status: ## show pod/hpa/pdb status
	kubectl get deployment,pods,hpa,pdb -n redemption -o wide

# scanning
scan: ## run IaC + k8s security scans
	checkov -d $(TF_DIR)/ --framework terraform
	kube-linter lint $(K8S_DIR)/

# testing
test: validate scan
	@echo "Infrastructure validation complete"

test-smoke: ## smoke tests against deployed env
	@echo "Running smoke tests against $(ENV) environment..."
	@kubectl --context=$(ENV) -n redemption get deployment redemption-service
	@kubectl --context=$(ENV) -n redemption rollout status deployment/redemption-service --timeout=60s
	@echo "Smoke tests passed"

# docs
docs-pdf: ## generate design doc PDF (needs pandoc)
	@which pandoc > /dev/null 2>&1 || (echo "pandoc not found: brew install pandoc"; exit 1)
	pandoc docs/design-document.md -o docs/design-document.pdf --pdf-engine=xelatex 2>/dev/null || \
		pandoc docs/design-document.md -o docs/design-document.pdf
	@echo "Generated docs/design-document.pdf"

clean: ## clean build artifacts
	rm -f $(TF_DIR)/tfplan docs/design-document.pdf
