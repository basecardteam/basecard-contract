# =================================================================
#                       Test Commands
# =================================================================

## Run all BaseCard tests
# Usage: make test
test:
	@echo "🧪 Running all tests..."
	@forge clean && forge test -vv
	@echo "✅ Tests complete!"

## Run BaseCard core tests (mint, edit, etc.)
# Usage: make test-core
test-core:
	@echo "🧪 Running BaseCard core tests..."
	@forge clean && forge test --match-contract BaseCardTest -vv
	@echo "✅ Core tests complete!"

## Run upgrade tests
# Usage: make test-upgrade
test-upgrade:
	@echo "🧪 Running BaseCard upgrade tests..."
	@forge clean && forge test --match-contract BaseCardUpgradeTest -vvv
	@echo "✅ Upgrade tests complete!"

## Run fork upgrade tests (requires RPC)
# Usage: make test-fork-upgrade
test-fork-upgrade:
	@echo "🧪 Running upgrade simulation on Fork..."
	@forge clean && forge test --match-contract BaseCardForkUpgradeTest --fork-url base_sepolia -vvv
	@echo "✅ Fork upgrade tests complete!"

# =============================================================
#                   Local Development Scripts
# =============================================================

## Mint NFT on local Anvil network (for testing)
# Usage: make mint-local
mint-local:
	@echo "🎨 Minting NFT on local network..."
	@forge script script/MintToken.s.sol:MintToken --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
	@echo "✅ Minting complete!"

## Upgrade to V2 on local network
# Usage: make upgrade-local
upgrade-local:
	@echo "⬆️  Upgrading to V2 on local network..."
	@forge script script/UpgradeToV2.s.sol:UpgradeToV2 --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
	@echo "✅ Upgrade complete!"

## Upgrade to V2 on testnet
# Usage: make upgrade-testnet
upgrade-testnet:
	@echo "⬆️  Upgrading to V2 on Base Sepolia..."
	@forge clean && forge script script/UpgradeToV2.s.sol:UpgradeBaseCardToV2 --fork-url base_sepolia --broadcast -vvvv --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_SENDER)
	@echo "✅ Upgrade complete!"
