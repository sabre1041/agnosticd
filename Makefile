ENV_TYPE=base-infra
CLOUD_PROVIDER=ec2
SANDBOX=1

# Adjust GUID to taste e.g. make deploy GUID=foo-01

GUID=my-guid-0$(SANDBOX)
OUTPUT_HOME=/tmp/output_dir
OUTPUT_DIR=$(OUTPUT_HOME)/$(GUID)-$(CLOUD_PROVIDER)
BACKUP_HOME=~/tmp/

# TODO: ~/tmp seems to fail, related to accessing tha ssh file at least in aws's ping during post_infra
# ~/tmp persists through reboots which can be useful
# showroom0$(SANDBOX)

PLAYBOOK_DIR=ansible

# AWS Uses Sandbox creds typically

SECRETS_DIR=~/secrets
SECRETS_FILE=$(SECRETS_DIR)/secrets-sandbox0$(SANDBOX).yaml

#SECRETS_ANSIBLE_VAULT_PASSWORD_FILE=$(SECRETS_DIR)/secret-ansible-vault-babylon-gpte_vault_0

VARS_DIR=~/vars
VARS_FILE=$(VARS_DIR)/vars-sandbox0$(SANDBOX)-$(CLOUD_PROVIDER).yaml

TARGET ?= bastion
ROLE ?= test-empty-role
EXTRA_ARGS=
USER_EXTRA_ARGS=
# Adjust to taste

: ## TIP! make supports tab completion with *modern* shells e.g. zsh etc
: ## e.g. make depl<TAB> == make deploy 
: ## 

.SILENT: setup my-env ssh-target

help: ## Show this help - technically unnecessary as `make` alone will do
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", ($$2=="" ? "" : $$1 ),  $$2}' 

# Thanks to victoria.dev for the above syntax
# https://victoria.dev/blog/how-to-create-a-self-documenting-makefile/

env: ## Confirm env setup
	@echo "\n\nActivate a virtualenv if required\n"
	@type python3
	@printf "Python3 version is: "
	@python3 --version
	@type ansible
	@ansible --version
	@printf "ENV VARS containing ANSIBLE: "
	@-env | grep ANSIBLE || echo "None"

ansible-execute: ## Execute ansible-playbook with PLAYBOOK of choice
	mkdir -p $(OUTPUT_DIR); \
	export ANSIBLE_LOG_PATH=$(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID).log; \
		ansible-playbook $(PLAYBOOK_DIR)/$(PLAYBOOK) \
		-e @$(VARS_FILE) \
		-e @$(SECRETS_FILE) \
		-e output_dir=$(OUTPUT_DIR) \
		-e env_type=$(ENV_TYPE) \
		-e guid=$(GUID) \
		$(USER_EXTRA_ARGS) $(EXTRA_ARGS)

deploy: ## Deploy normally with package updates etc (can be slow)
	$(MAKE) ansible-execute PLAYBOOK=main.yml 

deploy-fast: ## Deploy fast without package updates etc
	$(MAKE) ansible-execute PLAYBOOK=main.yml EXTRA_ARGS="-e update_packages=false"	

role-runner: ## Deploy fast without package updates etc
	$(MAKE) ansible-execute PLAYBOOK=role_runner.yml EXTRA_ARGS="-e role=$(ROLE)"	

destroy: ## Destroy the config
	$(MAKE) ansible-execute PLAYBOOK=destroy.yml

# user-data: ## Assumes an existing output_dir, outputs contenst of user-data.yaml
# 	ansible-playbook rhdp.agnostic_utilities.agd_user_info.yml -e output_dir=$(OUTPUT_DIR) 
	
ssh-target: ## ssh to your bastion by default or use `make ssh-target target=hostname` 
	ssh -F $(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID)_ssh_conf $(TARGET)

ssh: ## ssh to your bastion by default or use `make ssh target=hostname` 
	ssh -F $(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID)_ssh_conf $(TARGET)

user-data: ## Output user-data
	cat $(OUTPUT_DIR)/user-data.yaml

user-info: ## Output user-info
	cat $(OUTPUT_DIR)/user-info.yaml

last-status: ## Output last status file
	ls -l $(OUTPUT_DIR)/status.txt

update-status: ## Update status file
	$(MAKE) ansible-execute PLAYBOOK=lifecycle_entry_point.yml EXTRA_ARGS="-e ACTION=status"

stop: ## Suspend, stop, instances
	$(MAKE) ansible-execute PLAYBOOK=lifecycle_entry_point.yml EXTRA_ARGS="-e ACTION=stop"

start: ## Start stopped instances
	$(MAKE) ansible-execute PLAYBOOK=lifecycle_entry_point.yml EXTRA_ARGS="-e ACTION=start"

bounce: ## Bounce the deploy IE stop then start
bounce: stop start

showroom-remove: ## Remove showroom
	ansible-playbook \
		~/.ansible/collections/ansible_collections/rhdp/agnostic_utilities/playbooks/remove_showroom.yml \
		-i $(OUTPUT_DIR)/inventory_post_software.yaml \
		-e @$(OUTPUT_DIR)/user-data.yaml

showroom-install: ## Install showroom
	ANSIBLE_ROLES_PATH=../../roles \
	ansible-playbook \
		~/.ansible/collections/ansible_collections/rhdp/agnostic_utilities/playbooks/agd_role_runner.yml \
		-i $(OUTPUT_DIR)/inventory_post_software.yaml \
		-e @$(OUTPUT_DIR)/user-data.yaml \
		-e role=showroom
	
backup-output: ## Backup the output dir
	cp -r $(OUTPUT_HOME) $(BACKUP_HOME)

restore-output: ## Backup the output dir
	cp -r $(BACKUP_HOME)/output_dir /tmp/

relog: ## Zero out the ANSIBLE_LOG_PATH log file
	rm $(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID).log

