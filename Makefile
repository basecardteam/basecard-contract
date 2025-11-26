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
	@cast call $(PROXY_ADDRESS) "tokenURI(uint256)(string)" 0 --rpc-url http://127.0.0.1:8545
	@cast call $(PROXY_ADDRESS) "balanceOf(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:8545
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
	@forge script script/UpgradeToV2.s.sol:UpgradeToV2 --rpc-url $(NETWORK) --broadcast --verify -vvvv
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


call-contract-version:
	@echo "🔍 Calling contract version..."
	@cast call $(PROXY_ADDRESS) "version()"
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
	RESULT=$$(cast call $(BASE_CARD_ADDRESS) "tokenURI(uint256)(string)" $$TOKEN_ID --rpc-url "$(NETWORK)"); \
	echo "$$RESULT" |  tr -d '"' | sed 's/data:application\/json;base64,//' | base64 -d | jq . ; \
	echo "✅ Token URI retrieved!"

## @notice [조회] 특정 토큰 ID의 소셜 링크 값을 가져옵니다.
# Usage: make get-social TOKEN_ID=<id> KEY=<social_key>
get-social:
	@echo "🔍 Getting social value for key $(KEY) on Token ID $(TOKEN_ID)..."
	@cast call $(BASE_CARD_ADDRESS) "getSocial(uint256,string)(string)" $(TOKEN_ID) "$(KEY)" \
		--rpc-url "$(NETWORK)"

## @notice [조회] 특정 소셜 키가 허용되었는지 확인합니다.
# Usage: make is-allowed-social-key KEY=<social_key>
is-allowed-social-key:
	@echo "🔍 Checking if social key '$(KEY)' is allowed..."
	@cast call $(BASE_CARD_ADDRESS) "isAllowedSocialKey(string)(bool)" "$(KEY)" \
		--rpc-url "$(NETWORK)"

## @notice [조회] 특정 주소가 이미 민팅했는지 확인합니다.
# Usage: make check-has-minted ADDRESS=<user_address>
check-has-minted:
	@ADDRESS=$(filter-out $@,$(MAKECMDGOALS)); \
	echo "🔍 Checking mint status for $$ADDRESS..."; \
	cast call $(BASE_CARD_ADDRESS) "hasMinted(address)(bool)" $$ADDRESS --rpc-url "$(NETWORK)"

## @notice [조회] CARD 토큰의 Decimals를 가져옵니다.
# Usage: make get-token-decimals
get-token-decimals:
	@echo "🔍 Getting CARD token decimals..."
	@cast call $(BASE_CARD_ADDRESS) "tokenDecimals()(uint8)" --rpc-url "$(NETWORK)"

## @notice [쓰기] NFT에 소셜 링크를 연결합니다.
# Usage: make link-social TOKEN_ID=<id> KEY=<social_key> VALUE=<social_value>
link-social:
	@echo "🔗 Linking social account for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASE_CARD_ADDRESS) "linkSocial(uint256,string,string)" $(TOKEN_ID) "$(KEY)" "$(VALUE)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Social account linked!"

## @notice [쓰기] NFT의 닉네임을 업데이트합니다.
# Usage: make update-nickname TOKEN_ID=<id> NICKNAME=<new_nickname>
update-nickname:
	@echo "✏️ Updating nickname for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASE_CARD_ADDRESS) "updateNickname(uint256,string)" $(TOKEN_ID) "$(NICKNAME)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Nickname updated!"

## @notice [쓰기] NFT의 Bio(자기소개)를 업데이트합니다.
# Usage: make update-bio TOKEN_ID=<id> BIO=<new_bio>
update-bio:
	@echo "✏️ Updating bio for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASE_CARD_ADDRESS) "updateBio(uint256,string)" $(TOKEN_ID) "$(BIO)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Bio updated!"

## @notice [쓰기] NFT의 이미지 URI를 업데이트합니다.
# Usage: make update-image-uri TOKEN_ID=<id> IMAGE_URI=<new_image_uri>
update-image-uri:
	@echo "✏️ Updating image URI for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASE_CARD_ADDRESS) "updateImageURI(uint256,string)" $(TOKEN_ID) "$(IMAGE_URI)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Image URI updated!"

## @notice [쓰기] NFT의 Basename을 업데이트합니다.
# Usage: make update-basename TOKEN_ID=<id> BASENAME=<new_basename>
update-basename:
	@echo "✏️ Updating basename for Token ID $(TOKEN_ID) on $(NETWORK)..."
	@cast send $(BASE_CARD_ADDRESS) "updateBasename(uint256,string)" $(TOKEN_ID) "$(BASENAME)" \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Basename updated!"


# =============================================================
#          Owner Functions (cast send - PRIVATE_KEY 필요)
# =============================================================

## @notice [관리자] 소셜 링크 허용 목록을 관리합니다.
# Usage: make set-allowed-social-key KEY=<key> IS_ALLOWED=<true_or_false>
set-allowed-social-key:
	@echo "🔑 Setting allowed social key: $(KEY) to $(IS_ALLOWED)..."
	@cast send $(BASE_CARD_ADDRESS) "setAllowedSocialKey(string,bool)" "$(KEY)" $(IS_ALLOWED) \
	--rpc-url "$(NETWORK)" --private-key $(PRIVATE_KEY)
	@echo "✅ Key status updated!"

# wallet list
wallet-list:
	@cast wallet list

# import deployer wallet
wallet-import:
	@echo "🔑 Importing deployer wallet..."
	@cast wallet import deployer --mnemonic .mn
	@echo "✅ Deployer wallet imported!"

# =============================================================
#          Positional Arguments Handler
# =============================================================

# This target handles positional arguments for commands that support them
# It prevents make from trying to execute the argument as a target
%:
	@:
