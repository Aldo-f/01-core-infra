# Ansible Vault Master Key - HERMES CREDENTIALS
# NEVER commit this file to git
# NEVER share this file
# Location: dev/01-core-infra/vaults/master.key
# Permissions: chmod 600 (owner read/write only)

# The master key is used by:
# 1. Ansible Vault to encrypt/decrypt hermes-credentials.yml
# 2. GitHub Actions (via secret ANSIBLE_VAULT_MASTER_KEY) to decrypt at runtime
# 3. Local development (via --vault-password-file)

# SECURITY PROTOCOL:
# - This key file should be created ONCE with: openssl rand -base64 32
# - The key should be stored in GitHub Secrets as ANSIBLE_VAULT_MASTER_KEY
# - DO NOT store this file in version control
# - DO NOT email or share this file via unsecured channels

# Usage examples:
# ansible-vault decrypt --vault-password-file dev/01-core-infra/vaults/master.key dev/01-core-infra/vaults/hermes-credentials.yml
# ansible-playbook site.yml --vault-password-file dev/01-core-infra/vaults/master.key