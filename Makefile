.PHONY: help install deploy nomad consul vault edge all clean check validate

# Default target
.DEFAULT_GOAL := help

# Variables
ANSIBLE_PATH = bootstrap
HOSTS_FILE = hosts.yml
ANSIBLE_OPTS = -i $(HOSTS_FILE)

# Help
help:
	@echo "Homelab Infrastructure Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make install         Install Ansible requirements"
	@echo "  make deploy          Deploy the entire infrastructure"
	@echo "  make nomad           Deploy only Nomad components"
	@echo "  make consul          Deploy only Consul components"
	@echo "  make vault           Deploy only Vault components"
	@echo "  make edge            Deploy only edge node components"
	@echo "  make all             Deploy all components (same as deploy)"
	@echo "  make clean           Clean local Ansible artifacts (retry files, etc.)"
	@echo "  make check           Check connectivity to hosts"
	@echo "  make validate        Validate Ansible playbooks"
	@echo ""

# Install Ansible requirements
install:
	@echo "Installing Ansible requirements..."
	@cd $(ANSIBLE_PATH) && ansible-galaxy install -r requirements.yml
	@echo "Requirements installed successfully."

# Deploy entire infrastructure
deploy: install
	@echo "Deploying entire infrastructure..."
	@cd $(ANSIBLE_PATH) && ansible-playbook $(ANSIBLE_OPTS) site.yml
	@echo "Infrastructure deployed successfully."

# Deploy only Nomad components
nomad: install
	@echo "Deploying Nomad components..."
	@cd $(ANSIBLE_PATH) && ansible-playbook $(ANSIBLE_OPTS) site.yml --tags nomad
	@echo "Nomad components deployed successfully."

# Deploy only Consul components
consul: install
	@echo "Deploying Consul components..."
	@cd $(ANSIBLE_PATH) && ansible-playbook $(ANSIBLE_OPTS) site.yml --tags consul
	@echo "Consul components deployed successfully."

# Deploy only Vault components
vault: install
	@echo "Deploying Vault components..."
	@cd $(ANSIBLE_PATH) && ansible-playbook $(ANSIBLE_OPTS) site.yml --tags vault
	@echo "Vault components deployed successfully."

# Deploy only edge components
edge: install
	@echo "Deploying edge node components..."
	@cd $(ANSIBLE_PATH) && ansible-playbook $(ANSIBLE_OPTS) site.yml --limit edge_nodes
	@echo "Edge components deployed successfully."

# Deploy all components (same as deploy)
all: deploy

# Clean local Ansible artifacts
clean:
	@echo "Cleaning Ansible artifacts..."
	@find $(ANSIBLE_PATH) -name "*.retry" -type f -delete
	@echo "Cleaning complete."

# Check connectivity to hosts
check:
	@echo "Checking connectivity to hosts..."
	@cd $(ANSIBLE_PATH) && ansible all $(ANSIBLE_OPTS) -m ping
	@echo "Connectivity check complete."

# Validate Ansible playbooks
validate:
	@echo "Validating Ansible playbooks..."
	@cd $(ANSIBLE_PATH) && ansible-playbook $(ANSIBLE_OPTS) site.yml --syntax-check
	@echo "Validation complete." 