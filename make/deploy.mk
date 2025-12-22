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
	echo "📝 Updating backend/.env..."; \
	if [ -f "../backend/.env" ]; then \
		if grep -q "^BASECARD_CONTRACT_ADDRESS=" ../backend/.env; then \
			sed -i '' "s|^BASECARD_CONTRACT_ADDRESS=.*|BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR|" ../backend/.env; \
		else \
			echo "BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR" >> ../backend/.env; \
		fi; \
		echo "✅ backend/.env updated with $$PROXY_ADDR"; \
	else \
		echo "⚠️  backend/.env not found"; \
	fi; \
	echo ""; \
	echo "📝 Updating contract/.env..."; \
	if [ -f ".env" ]; then \
		if grep -q "^BASECARD_CONTRACT_ADDRESS=" .env; then \
			sed -i '' "s|^BASECARD_CONTRACT_ADDRESS=.*|BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR|" .env; \
		else \
			echo "BASECARD_CONTRACT_ADDRESS=$$PROXY_ADDR" >> .env; \
		fi; \
		echo "✅ contract/.env updated with $$PROXY_ADDR"; \
	else \
		echo "⚠️  contract/.env not found"; \
	fi; \
	$(MAKE) sync-abi
