# =================================================================
# ======================= DEPLOYMENT COMMANDS =====================
# =================================================================

# .env 파일로부터 환경 변수를 불러옵니다.
# .env 파일에 BASE_SEPOLIA_RPC_URL, BASESCAN_API_KEY, PRIVATE_KEY를 반드시 설정해야 합니다.
include .env
export

# =============================================================
#          Deploy Contract
# =============================================================

# Deploy contracts to a specified network.
# Usage: make deploy NETWORK=<network_name>
# Example: make deploy NETWORK=base_sepolia
deploy-testnet:
	@echo "🚀 Deploying contracts to base_sepolia..."
	@forge script script/DeployBaseCard.s.sol --rpc-url base_sepolia --broadcast --ffi --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_SENDER)
	@echo "✅ Deployment successful!"

## @notice 테스트넷에 배포하고 자동으로 ABI와 주소를 동기화합니다.
# Usage: make deploy-and-sync
deploy-and-sync:
	@echo "🚀 Deploying contracts to base_sepolia..."
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
	$(MAKE) sync-all ADDRESS=$$PROXY_ADDR

deploy-local:
	@echo "🚀 Deploying contracts to local Anvil network..."
	@forge script script/DeployBaseCard.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --ffi

# =============================================================
#          Upgrade Functions (UUPS Proxy)
# =============================================================

## @notice [로컬] 로컬넷에 배포된 프록시에 NFT를 민팅합니다 (테스트용)
# Usage: make mint-local
mint-local:
	@echo "🎨 Minting NFT on local network..."
	@forge script script/MintToken.s.sol:MintToken --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
	@echo "✅ Minting complete!"

check-token:	
	@echo "🔍 Checking token URI..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "tokenURI(uint256)(string)" 0 --rpc-url http://127.0.0.1:8545
	@cast call $(BASECARD_CONTRACT_ADDRESS) "balanceOf(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:8545
	@echo "✅ Token URI retrieved!"

## @notice [로컬] V1을 V2로 업그레이드하고 상태를 검증합니다
# Usage: make upgrade-to-v2-local
upgrade-to-v2-local:
	@echo "⬆️  Upgrading to V2 on local network..."
	@forge script script/UpgradeToV2.s.sol:UpgradeToV2 --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
	@echo "✅ Upgrade complete!"

## @notice [테스트넷] V1을 V2로 업그레이드하고 상태를 검증합니다
# Usage: make upgrade-to-v2 NETWORK=<network_name>
# Example: make upgrade-to-v2 NETWORK=base_sepolia
upgrade-to-v2:
	@echo "⬆️  Upgrading to V2 on $(NETWORK)..."
	@forge clean && forge script script/UpgradeToV2.s.sol:UpgradeBaseCardToV2 --fork-url base_sepolia --broadcast -vvvv  --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_SENDER)
	@echo "✅ Upgrade complete!"

## @notice BaseCard 기본 테스트 (업그레이드 없음)
# Usage: make test-basecard
test-basecard:
	@echo "🧪 Running BaseCard tests..."
	@forge clean && forge test --match-contract BaseCardTest --no-match-test Upgrade -vv
	@echo "✅ Tests complete!"

## @notice BaseCard 업그레이드 테스트
# Usage: make test-basecard-upgrade
test-basecard-upgrade:
	@echo "🧪 Running BaseCard upgrade tests..."
	@forge clean && forge test --match-contract BaseCardUpgradeTest -vvv
	@echo "✅ Upgrade tests complete!"

## @notice [Fork] 실제 배포된 컨트랙트를 기준으로 업그레이드 시뮬레이션
# Usage: make test-fork-upgrade
test-fork-upgrade:
	@echo "🧪 Running upgrade simulation on Fork..."
	@forge clean && forge test --match-contract BaseCardForkUpgradeTest --fork-url base_sepolia -vvv


call-contract-version:
	@echo "🔍 Calling contract version on $(NETWORK)..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "version()(string)" --rpc-url $(NETWORK)
	@echo "✅ Contract version retrieved!"


# =============================================================
#          Read Functions (cast call - 가스비 불필요)
# =============================================================

## @notice [조회] 특정 토큰 ID의 메타데이터 URI를 가져옵니다.
# Usage: make token-uri <id> or make token-uri TOKEN_ID=<id>
token-uri:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ] && [ -z "$(TOKEN_ID)" ]; then \
		echo "❌ Error: TOKEN_ID is required. Usage: make token-uri <id> or make token-uri TOKEN_ID=<id>"; \
		exit 1; \
	fi
	@TOKEN_ID=$${TOKEN_ID:-$(filter-out $@,$(MAKECMDGOALS))}; \
	echo "🔍 Getting tokenURI for Token ID $$TOKEN_ID on $(NETWORK)..."; \
	RESULT=$$(cast call $(BASECARD_CONTRACT_ADDRESS) "tokenURI(uint256)(string)" $$TOKEN_ID --rpc-url "$(NETWORK)"); \
	echo "$$RESULT" |  tr -d '"' | sed 's/data:application\/json;base64,//' | base64 -d | jq . ; \
	echo "✅ Token URI retrieved!"

## @notice [조회] 특정 토큰 ID의 소셜 링크 값을 가져옵니다.
# Usage: make get-social TOKEN_ID=<id> KEY=<social_key>
get-social:
	@echo "🔍 Getting social value for key $(KEY) on Token ID $(TOKEN_ID)..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "getSocial(uint256,string)(string)" $(TOKEN_ID) "$(KEY)" \
		--rpc-url "$(NETWORK)"

## @notice [조회] 특정 소셜 키가 허용되었는지 확인합니다.
# Usage: make is-allowed-social-key KEY=<social_key>
is-allowed-social-key:
	@echo "🔍 Checking if social key '$(KEY)' is allowed..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "isAllowedSocialKey(string)(bool)" "$(KEY)" \
		--rpc-url "$(NETWORK)"

## @notice [조회] 특정 주소가 이미 민팅했는지 확인합니다.
# Usage: make check-has-minted ADDRESS=<user_address>
check-has-minted:
	@ADDRESS=$(filter-out $@,$(MAKECMDGOALS)); \
	echo "🔍 Checking mint status for $$ADDRESS..."; \
	cast call $(BASECARD_CONTRACT_ADDRESS) "hasMinted(address)(bool)" $$ADDRESS --rpc-url "$(NETWORK)"

## @notice [조회] CARD 토큰의 Decimals를 가져옵니다.
# Usage: make get-token-decimals
get-token-decimals:
	@echo "🔍 Getting CARD token decimals..."
	@cast call $(BASECARD_CONTRACT_ADDRESS) "tokenDecimals()(uint8)" --rpc-url "$(NETWORK)"

## @notice [조회] 주소로 토큰 ID와 URI를 가져옵니다.
# Usage: make get-token-by-address ADDRESS=<user_address>
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

## @notice [쓰기] NFT에 소셜 링크를 연결합니다.
# Usage: make link-social TOKEN_ID=<id> KEY=<social_key> VALUE=<social_value>
link-social:
	@echo "🔗 Linking social account for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASECARD_CONTRACT_ADDRESS) "linkSocial(uint256,string,string)" $(TOKEN_ID) "$(KEY)" "$(VALUE)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Social account linked!"

## @notice [쓰기] NFT의 닉네임을 업데이트합니다.
# Usage: make update-nickname TOKEN_ID=<id> NICKNAME=<new_nickname>
update-nickname:
	@echo "✏️ Updating nickname for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASECARD_CONTRACT_ADDRESS) "updateNickname(uint256,string)" $(TOKEN_ID) "$(NICKNAME)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Nickname updated!"

## @notice [쓰기] NFT의 Bio(자기소개)를 업데이트합니다.
# Usage: make update-bio TOKEN_ID=<id> BIO=<new_bio>
update-bio:
	@echo "✏️ Updating bio for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASECARD_CONTRACT_ADDRESS) "updateBio(uint256,string)" $(TOKEN_ID) "$(BIO)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Bio updated!"

## @notice [쓰기] NFT의 이미지 URI를 업데이트합니다.
# Usage: make update-image-uri TOKEN_ID=<id> IMAGE_URI=<new_image_uri>
update-image-uri:
	@echo "✏️ Updating image URI for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASECARD_CONTRACT_ADDRESS) "updateImageURI(uint256,string)" $(TOKEN_ID) "$(IMAGE_URI)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Image URI updated!"

## @notice [쓰기] NFT의 Basename을 업데이트합니다.
# Usage: make update-basename TOKEN_ID=<id> BASENAME=<new_basename>
update-basename:
	@echo "✏️ Updating basename for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASECARD_CONTRACT_ADDRESS) "updateBasename(uint256,string)" $(TOKEN_ID) "$(BASENAME)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Basename updated!"


# =============================================================
#          Owner Functions (cast send - PRIVATE_KEY 필요)
# =============================================================

## @notice [관리자] 소셜 링크 허용 목록을 관리합니다.
# Usage: make set-allowed-social-key KEY=<key> IS_ALLOWED=<true_or_false>
set-allowed-social-key:
	@echo "🔑 Setting allowed social key: $(KEY) to $(IS_ALLOWED)..."
	@cast send $(BASECARD_CONTRACT_ADDRESS) "setAllowedSocialKey(string,bool)" "$(KEY)" $(IS_ALLOWED) \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Key status updated!"

## @notice [관리자] 마이그레이션 관리자 주소를 설정합니다.
# Usage: make set-migration-admin ADMIN=<admin_address>
set-migration-admin:
	@if [ -z "$(ADMIN)" ]; then \
		echo "⚠️  ADMIN not specified. Using DEPLOYER_SENDER: $(DEPLOYER_SENDER)"; \
		ADMIN=$(DEPLOYER_SENDER); \
	else \
		ADMIN=$(ADMIN); \
	fi; \
	echo "🔑 Setting migration admin to: $$ADMIN..."; \
	cast send $(BASECARD_CONTRACT_ADDRESS) "setMigrationAdmin(address)" $$ADMIN --rpc-url "$(NETWORK)" --account $(DEPLOYER_ACCOUNT)
	@echo "✅ Migration admin updated!"

# wallet list
wallet-list:
	@cast wallet list

# import deployer wallet
wallet-import:
	@echo "🔑 Importing deployer wallet..."
	@cast wallet import deployer --mnemonic .mn
	@echo "✅ Deployer wallet imported!"

# =============================================================
#          Development Sync Commands
# =============================================================

## @notice ABI를 miniapp으로 복사합니다.
# Usage: make sync-abi
sync-abi:
	@echo "📦 Syncing ABI to miniapp..."
	@cp out/BaseCard.sol/BaseCard.json ../miniapp/lib/abi/BaseCard.json
	@echo "✅ ABI synced to miniapp/lib/abi/BaseCard.json"

## @notice 컨트랙트 주소를 backend와 miniapp에 업데이트합니다.
# Usage: make update-contract-address ADDRESS=0x...
update-contract-address:
	@if [ -z "$(ADDRESS)" ]; then \
		echo "❌ Error: ADDRESS is required. Usage: make update-contract-address ADDRESS=0x..."; \
		exit 1; \
	fi
	@echo "🔄 Updating contract address to $(ADDRESS)..."
	@# Update backend/.env
	@if [ -f "../backend/.env" ]; then \
		if grep -q "^BASECARD_CONTRACT_ADDRESS=" ../backend/.env; then \
			sed -i '' 's|^BASECARD_CONTRACT_ADDRESS=.*|BASECARD_CONTRACT_ADDRESS=$(ADDRESS)|' ../backend/.env; \
		else \
			echo "BASECARD_CONTRACT_ADDRESS=$(ADDRESS)" >> ../backend/.env; \
		fi; \
		echo "  ✓ backend/.env updated"; \
	else \
		echo "  ⚠️  backend/.env not found"; \
	fi
	@# Update miniapp/.env.local
	@if [ -f "../miniapp/.env.local" ]; then \
		if grep -q "^NEXT_PUBLIC_BASECARD_CONTRACT_ADDRESS=" ../miniapp/.env.local; then \
			sed -i '' 's|^NEXT_PUBLIC_BASECARD_CONTRACT_ADDRESS=.*|NEXT_PUBLIC_BASECARD_CONTRACT_ADDRESS=$(ADDRESS)|' ../miniapp/.env.local; \
		else \
			echo "NEXT_PUBLIC_BASECARD_CONTRACT_ADDRESS=$(ADDRESS)" >> ../miniapp/.env.local; \
		fi; \
		echo "  ✓ miniapp/.env.local updated"; \
	else \
		echo "  ⚠️  miniapp/.env.local not found"; \
	fi
	@echo "✅ Contract address updated in all environments!"

## @notice ABI 동기화 + 컨트랙트 주소 업데이트를 한번에 수행합니다.
# Usage: make sync-all ADDRESS=0x...
sync-all: sync-abi update-contract-address
	@echo "🎉 All synced! Don't forget to restart your dev servers."

# =============================================================
#          Positional Arguments Handler
# =============================================================

# This target handles positional arguments for commands that support them
# It prevents make from trying to execute the argument as a target
%:
	@:
