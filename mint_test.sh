#!/bin/bash

# Load environment variables
if [ -f contract/.env ]; then
    export $(grep -v '^#' contract/.env | xargs)
elif [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it to run this script."
    exit 1
fi

# User provided data for testing
JSON_INPUT='{
  "card_data": {
    "imageUri": "ipfs://bafkreib2t6mwxfbtdmvyq4y353wfrzkx7xupy2l5krq34phl4j7lfa7nc4",
    "nickname": "Jeongseup",
    "role": "Developer",
    "bio": "abc"
  },
  "social_keys": [
    "twitter",
    "github",
    "farcaster"
  ],
  "social_values": [
    "@jeongseup",
    "Jeongseup",
    "@basecat"
  ]
}'

# If an argument is provided and it's a file, read it
if [ "$1" ]; then
  if [ -f "$1" ]; then
    JSON_INPUT=$(cat "$1")
  else
    # Assume it's a JSON string
    JSON_INPUT="$1"
  fi
fi

echo "Parsing JSON..."

# Extract values using jq (keep quotes for cast parsing)
NICKNAME=$(echo "$JSON_INPUT" | jq '.card_data.nickname')
ROLE=$(echo "$JSON_INPUT" | jq '.card_data.role')
BIO=$(echo "$JSON_INPUT" | jq '.card_data.bio')
IMAGE_URI=$(echo "$JSON_INPUT" | jq '.card_data.imageUri')

# Extract arrays and format for cast
# cast expects arrays like ["item1","item2"] which jq outputs by default, 
# but we need to ensure they are properly quoted for the shell command if they contain spaces.
# Actually, cast send expects string[] as "[val1,val2]"
SOCIAL_KEYS=$(echo "$JSON_INPUT" | jq -r '.social_keys | "[" + (map(.) | join(",")) + "]"')
SOCIAL_VALUES=$(echo "$JSON_INPUT" | jq -r '.social_values | "[" + (map(.) | join(",")) + "]"')

echo "Minting BaseCard..."
echo "Nickname: $NICKNAME"
echo "Role: $ROLE"
echo "Bio: $BIO"
echo "ImageURI: $IMAGE_URI"
echo "Social Keys: $SOCIAL_KEYS"
echo "Social Values: $SOCIAL_VALUES"

# Check required env vars
if [ -z "$BASECARD_CONTRACT_ADDRESS" ]; then
  echo "Error: BASECARD_CONTRACT_ADDRESS is not set in .env"
  echo "Using default for testing..."
  # You can set a default here if you want
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY is not set in .env"
    exit 1
fi

if [ -z "$RECIPIENT" ]; then
    echo "Error: RECIPIENT is not set. Please set RECIPIENT env var to the address receiving the card."
    exit 1
fi

echo "Recipient: $RECIPIENT"

# Call migrateBaseCardFromTestnet
# Function: migrateBaseCardFromTestnet(address _recipient, CardData memory _initialCardData, string[] memory _socialKeys, string[] memory _socialValues)
# CardData Struct: (string imageURI, string nickname, string role, string bio)
cast send "$BASECARD_CONTRACT_ADDRESS" \
  "mintBaseCard((string,string,string,string),string[],string[])" \
  "($IMAGE_URI,$NICKNAME,$ROLE,$BIO)" \
  "$SOCIAL_KEYS" \
  "$SOCIAL_VALUES" \
  --rpc-url base_sepolia \
  --account ${DEPLOYER_ACCOUNT}
