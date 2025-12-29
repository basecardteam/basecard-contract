# =================================================================
#                    Read Functions (cast call)
# =================================================================

## Get tokenURI for a specific token ID
# Usage: make token-uri <id> or make token-uri TOKEN_ID=<id>
token-uri:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ] && [ -z "$(TOKEN_ID)" ]; then \
		echo "❌ Error: TOKEN_ID is required. Usage: make token-uri <id>"; \
		exit 1; \
	fi
	@TOKEN_ID=$${TOKEN_ID:-$(filter-out $@,$(MAKECMDGOALS))}; \
	echo "🔍 Getting tokenURI for Token ID $$TOKEN_ID on $(NETWORK)..."; \
	RESULT=$$(cast call $(BASECARD_CONTRACT_ADDRESS) "tokenURI(uint256)(string)" $$TOKEN_ID --rpc-url "$(NETWORK)"); \
	echo "$$RESULT" | tr -d '"' | sed 's/data:application\/json;base64,//' | base64 -d | jq . ; \
	echo "✅ Token URI retrieved!"

## Get social link value for a token
# Usage: make get-social TOKEN_ID=<id> KEY=<social_key>
get-social:
	@echo "🔍 Getting social value for key $(KEY) on Token ID $(TOKEN_ID)..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "getSocial(uint256,string)(string)" $(TOKEN_ID) "$(KEY)" \
		--rpc-url "$(NETWORK)"

## Check if a social key is allowed
# Usage: make is-allowed-social-key KEY=<social_key>
is-allowed-social-key:
	@echo "🔍 Checking if social key '$(KEY)' is allowed..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "isAllowedSocialKey(string)(bool)" "$(KEY)" \
		--rpc-url "$(NETWORK)"

## Check if a role is allowed
# Usage: make is-allowed-role ROLE=<role>
is-allowed-role:
	@echo "🔍 Checking if role '$(ROLE)' is allowed..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "isAllowedRole(string)(bool)" "$(ROLE)" \
		--rpc-url "$(NETWORK)"

## Check if an address has minted
# Usage: make check-has-minted <address>
check-has-minted:
	@ADDRESS=$(filter-out $@,$(MAKECMDGOALS)); \
	echo "🔍 Checking mint status for $$ADDRESS..."; \
	cast call $(BASECARD_CONTRACT_ADDRESS) "hasMinted(address)(bool)" $$ADDRESS --rpc-url "$(NETWORK)"

## Get token ID and URI by address
# Usage: make get-token-by-address <address>
get-token-by-address:
	@ADDRESS=$(filter-out $@,$(MAKECMDGOALS)); \
	if [ -z "$$ADDRESS" ]; then \
		echo "❌ Error: ADDRESS is required."; \
		exit 1; \
	fi; \
	echo "🔍 Getting Token ID for address $$ADDRESS..."; \
	TOKEN_ID=$$(cast call $(BASECARD_CONTRACT_ADDRESS) "tokenIdOf(address)(uint256)" $$ADDRESS --rpc-url "$(NETWORK)"); \
	if [ "$$TOKEN_ID" = "0" ]; then \
		echo "❌ No token found for this address."; \
		exit 1; \
	fi; \
	echo "✅ Token ID found: $$TOKEN_ID"; \
	echo "🔍 Getting tokenURI..."; \
	$(MAKE) token-uri TOKEN_ID=$$TOKEN_ID

version:
	@echo "🔍 Getting contract version..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "version()(string)" --rpc-url $(NETWORK) 2>/dev/null || echo "❌ version() not available"

## Get token by address on Testnet
# Usage: make get-token-testnet <address>
get-token-testnet:
	@if [ ! -f .env.dev ]; then echo "❌ .env.dev not found"; exit 1; fi
	@export $$(grep -v '^#' .env.dev | xargs) && \
	$(MAKE) get-token-by-address $(filter-out $@,$(MAKECMDGOALS)) \
		NETWORK="base_sepolia" \
		BASECARD_CONTRACT_ADDRESS=$$BASECARD_CONTRACT_ADDRESS

## Get token by address on Mainnet
# Usage: make get-token-mainnet <address>
get-token-mainnet:
	@if [ ! -f .env.prod ]; then echo "❌ .env.prod not found"; exit 1; fi
	@export $$(grep -v '^#' .env.prod | xargs) && \
	$(MAKE) get-token-by-address $(filter-out $@,$(MAKECMDGOALS)) \
		NETWORK="base_mainnet" \
		BASECARD_CONTRACT_ADDRESS=$$BASECARD_CONTRACT_ADDRESS

