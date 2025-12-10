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
  "token_id": 1,
  "card_data": {
    "imageUri": "ipfs://bafkreib2t6mwxfbtdmvyq4y353wfrzkx7xupy2l5krq34phl4j7lfa7nc4",
    "nickname": "UpdatedNickname",
    "role": "Senior Developer",
    "bio": "Updated bio text"
  },
  "social_keys": [
    "twitter",
    "github",
    "farcaster"
  ],
  "social_values": [
    "@updated_twitter",
    "UpdatedGithub",
    "@updated_farcaster"
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
TOKEN_ID=$(echo "$JSON_INPUT" | jq -r '.token_id')
NICKNAME=$(echo "$JSON_INPUT" | jq '.card_data.nickname')
ROLE=$(echo "$JSON_INPUT" | jq '.card_data.role')
BIO=$(echo "$JSON_INPUT" | jq '.card_data.bio')
IMAGE_URI=$(echo "$JSON_INPUT" | jq '.card_data.imageUri')

# Extract arrays and format for cast
SOCIAL_KEYS=$(echo "$JSON_INPUT" | jq -r '.social_keys | "[" + (map(.) | join(",")) + "]"')
SOCIAL_VALUES=$(echo "$JSON_INPUT" | jq -r '.social_values | "[" + (map(.) | join(",")) + "]"')

echo "Editing BaseCard..."
echo "Token ID: $TOKEN_ID"
echo "Nickname: $NICKNAME"
echo "Role: $ROLE"
echo "Bio: $BIO"
echo "ImageURI: $IMAGE_URI"
echo "Social Keys: $SOCIAL_KEYS"
echo "Social Values: $SOCIAL_VALUES"

# Check required env vars
if [ -z "$BASECARD_CONTRACT_ADDRESS" ]; then
  echo "Error: BASECARD_CONTRACT_ADDRESS is not set in .env"
  exit 1
fi

if [ -z "$DEPLOYER_ACCOUNT" ]; then
    echo "Error: DEPLOYER_ACCOUNT is not set in .env"
    exit 1
fi

# Call editBaseCard
# Function: editBaseCard(uint256 _tokenId, CardData memory _newCardData, string[] memory _socialKeys, string[] memory _socialValues)
# CardData Struct: (string imageURI, string nickname, string role, string bio)
cast send "$BASECARD_CONTRACT_ADDRESS" \
  "editBaseCard(uint256,(string,string,string,string),string[],string[])" \
  "$TOKEN_ID" \
  "($IMAGE_URI,$NICKNAME,$ROLE,$BIO)" \
  "$SOCIAL_KEYS" \
  "$SOCIAL_VALUES" \
  --rpc-url base_sepolia \
  --account ${DEPLOYER_ACCOUNT}
