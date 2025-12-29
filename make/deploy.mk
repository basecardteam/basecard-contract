# =================================================================
#                       Deploy Commands
# =================================================================

# Common deployment logic (not to be run directly)
_deploy_run:
	@echo "🚀 Deploying contracts to $(NETWORK_NAME)..."
	@echo "📄 Using Env File: $(ENV_FILE)"
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "❌ Error: $(ENV_FILE) not found!"; \
		exit 1; \
	fi
	@# Load variables from env file for the shell execution
	@export $$(grep -v '^#' $(ENV_FILE) | xargs) && \
	forge script script/DeployBaseCard.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--ffi \
		--account $${DEPLOYER_ACCOUNT} \
		--sender $${DEPLOYER_SENDER}

	@echo "✅ Deployment successful!"
	@echo ""
	@echo "📦 Extracting proxy address from broadcast/DeployBaseCard.s.sol/$(CHAIN_ID)/run-latest.json..."
	@PROXY_ADDR=$$(cat broadcast/DeployBaseCard.s.sol/$(CHAIN_ID)/run-latest.json | jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress'); \
	if [ -z "$$PROXY_ADDR" ]; then \
		echo "❌ Could not find proxy address in broadcast"; \
		exit 1; \
	fi; \
	echo "🔗 Proxy Address: $$PROXY_ADDR"; \
	echo ""; \
	echo "📝 Updating backend/$(ENV_FILE) ..."; \
	if [ -f "../backend/$(ENV_FILE)" ]; then \
		if grep -q "^BASECARD_CONTRACT_ADDRESS=" "../backend/$(ENV_FILE)"; then \
			sed -i '' "s|^BASECARD_CONTRACT_ADDRESS=.*|BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR|" "../backend/$(ENV_FILE)"; \
		else \
			echo "BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR" >> "../backend/$(ENV_FILE)"; \
		fi; \
		echo "✅ backend/$(ENV_FILE) updated with $$PROXY_ADDR"; \
	else \
		echo "⚠️  backend/$(ENV_FILE) not found"; \
	fi; \
	echo ""; \
	echo "📝 Updating contract/$(ENV_FILE)..."; \
	if [ -f "../contract/$(ENV_FILE)" ]; then \
		if grep -q "^BASECARD_CONTRACT_ADDRESS=" "../contract/$(ENV_FILE)"; then \
			sed -i '' "s|^BASECARD_CONTRACT_ADDRESS=.*|BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR|" "../contract/$(ENV_FILE)"; \
		else \
			echo "BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR" >> "../contract/$(ENV_FILE)"; \
		fi; \
		echo "✅ contract/$(ENV_FILE) updated with $$PROXY_ADDR"; \
	else \
		echo "⚠️  contract/$(ENV_FILE) not found"; \
	fi; \
	$(MAKE) sync-abi

## Deploy to Testnet (Base Sepolia)
# Usage: make deploy-testnet
deploy-testnet: ENV_FILE=.env.dev
deploy-testnet: RPC_URL=base_sepolia
deploy-testnet: NETWORK_NAME="Base Sepolia"
deploy-testnet: CHAIN_ID=84532
deploy-testnet: _deploy_run

## Deploy to Mainnet (Base Mainnet)
# Usage: make deploy-mainnet
deploy-mainnet: ENV_FILE=.env.prod
deploy-mainnet: RPC_URL=base
deploy-mainnet: NETWORK_NAME="Base Mainnet"
deploy-mainnet: CHAIN_ID=8453
deploy-mainnet: _deploy_run
