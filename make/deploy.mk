# =================================================================
#                       Deploy Commands
# =================================================================

## Deploy to testnet and sync ABI
# Usage: make deploy-testnet
deploy-testnet:
	@echo "🚀 Deploying contracts to Base Sepolia..."
	@forge script script/DeployBaseCard.s.sol --rpc-url base_sepolia --broadcast --ffi --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_SENDER)
	@echo "✅ Deployment successful!"
	@echo ""
	@echo "📦 Extracting proxy address from broadcast..."
	@PROXY_ADDR=$$(cat broadcast/DeployBaseCard.s.sol/84532/run-latest.json | jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress'); \
	if [ -z "$$PROXY_ADDR" ]; then \
		echo "❌ Could not find proxy address in broadcast"; \
		exit 1; \
	fi; \
	echo "🔗 Proxy Address: $$PROXY_ADDR"; \
	echo ""; \
	$(MAKE) sync-abi
