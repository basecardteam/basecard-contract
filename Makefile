# =================================================================
#                       BaseCard Makefile
# =================================================================

include .env
export

include make/deploy.mk
include make/test.mk
include make/utils.mk

# =============================================================
#                      Development Commands
# =============================================================

## Build contracts
build:
	@forge build

## Format code
fmt:
	@forge fmt

## Clean artifacts
clean:
	@forge clean

## Sync ABI to miniapp
sync-abi:
	@echo "📦 Syncing ABI to miniapp..."
	@cp out/BaseCard.sol/BaseCard.json ../miniapp/lib/abi/BaseCard.json
	@echo "✅ ABI synced to miniapp/lib/abi/BaseCard.json"

# =============================================================
#                 Positional Arguments Handler
# =============================================================

%:
	@:
