# BaseCard Contract Workflow

This document describes the state transitions and validation flows for the BaseCard NFT contract.

## Architecture Overview

```mermaid
flowchart TB
    subgraph Storage["📦 BaseCardStorage (ERC7201)"]
        S1["_nextTokenId"]
        S2["_cardData[tokenId]"]
        S3["hasMinted[address]"]
        S4["_socials[tokenId][key]"]
        S5["_allowedSocialKeys[key]"]
        S6["_allowedRoles[role]"]
        S7["ownerToTokenId[address]"]
        S8["allSocialKeys[]"]
        S9["allRoles[]"]
    end

    subgraph Functions["⚙️ Core Functions"]
        F1["mintBaseCard()"]
        F2["editBaseCard()"]
        F3["linkSocial()"]
        F4["updateNickname()"]
        F5["updateBio()"]
        F6["updateImageURI()"]
    end

    subgraph Admin["🔐 Admin Functions"]
        A1["setAllowedSocialKey()"]
        A2["setAllowedRole()"]
    end

    F1 --> V1["_validateCardData()"]
    F2 --> V1
    V1 --> S6
```

---

## CardData Validation Flow

```mermaid
flowchart LR
    subgraph Input["📥 CardData"]
        I1["nickname"]
        I2["imageURI"]
        I3["role"]
        I4["bio"]
    end

    subgraph Validation["✅ _validateCardData()"]
        V1{"nickname == ''?"}
        V2{"imageURI == ''?"}
        V3{"role in allowedRoles?"}
    end

    I1 --> V1
    V1 -->|Yes| E1["❌ EmptyNickname"]
    V1 -->|No| V2

    I2 --> V2
    V2 -->|Yes| E2["❌ EmptyImageURI"]
    V2 -->|No| V3

    I3 --> V3
    V3 -->|No| E3["❌ NotAllowedRole"]
    V3 -->|Yes| OK["✅ Valid"]

    I4 --> OK
```

| Field      | Validation              | Can be empty? |
| ---------- | ----------------------- | ------------- |
| `nickname` | Required                | ❌ No         |
| `imageURI` | Required                | ❌ No         |
| `role`     | Must be in allowedRoles | ❌ No         |
| `bio`      | Optional                | ✅ Yes        |

---

## mintBaseCard Flow

```mermaid
sequenceDiagram
    participant User
    participant Contract
    participant Storage

    User->>Contract: mintBaseCard(cardData, socialKeys, socialValues)

    Contract->>Storage: Check hasMinted[msg.sender]
    alt Already Minted
        Contract-->>User: ❌ AlreadyMinted
    end

    Contract->>Contract: Validate array lengths
    Contract->>Contract: _validateCardData(cardData)

    Contract->>Storage: hasMinted[msg.sender] = true
    Contract->>Storage: tokenId = _nextTokenId++
    Contract->>Storage: _cardData[tokenId] = cardData
    Contract->>Storage: ownerToTokenId[msg.sender] = tokenId

    loop Each Social Key
        Contract->>Storage: Validate _allowedSocialKeys[key]
        Contract->>Storage: _socials[tokenId][key] = value
        Contract-->>User: 📢 SocialLinked
    end

    Contract->>User: _safeMint(msg.sender, tokenId)
    Contract-->>User: 📢 MintBaseCard
```

---

## editBaseCard Flow

```mermaid
sequenceDiagram
    participant User
    participant Contract
    participant Storage

    User->>Contract: editBaseCard(tokenId, newCardData, socialKeys, socialValues)

    Contract->>Storage: Verify ownerOf(tokenId) == msg.sender
    alt Not Owner
        Contract-->>User: ❌ NotTokenOwner
    end

    Contract->>Contract: Validate array lengths
    Contract->>Contract: _validateCardData(newCardData)
    Contract->>Storage: _cardData[tokenId] = newCardData

    loop Each Social Key
        Contract->>Storage: Validate _allowedSocialKeys[key]
        alt value == ""
            Contract->>Storage: delete _socials[tokenId][key]
            Contract-->>User: 📢 SocialUnlinked
        else value != ""
            Contract->>Storage: _socials[tokenId][key] = value
            Contract-->>User: 📢 SocialLinked
        end
    end

    Contract-->>User: 📢 BaseCardEdited
```

---

## linkSocial Flow

```mermaid
sequenceDiagram
    participant User
    participant Contract
    participant Storage

    User->>Contract: linkSocial(tokenId, key, value)

    Contract->>Storage: Verify ownerOf(tokenId) == msg.sender
    alt Not Owner
        Contract-->>User: ❌ NotTokenOwner
    end

    Contract->>Storage: Validate _allowedSocialKeys[key]
    alt Not Allowed
        Contract-->>User: ❌ NotAllowedSocialKey
    end

    alt value == ""
        Contract->>Storage: delete _socials[tokenId][key]
        Contract-->>User: 📢 SocialUnlinked
    else value != ""
        Contract->>Storage: _socials[tokenId][key] = value
        Contract-->>User: 📢 SocialLinked
    end
```

---

## Individual Update Functions

| Function           | Validation      | Updates                       |
| ------------------ | --------------- | ----------------------------- |
| `updateNickname()` | Cannot be empty | `_cardData[tokenId].nickname` |
| `updateBio()`      | Allows empty    | `_cardData[tokenId].bio`      |
| `updateImageURI()` | Cannot be empty | `_cardData[tokenId].imageURI` |

> All update functions require `onlyTokenOwner` modifier.

---

## Allowed Roles

| Role        | Description                                           |
| ----------- | ----------------------------------------------------- |
| `Developer` | Build amazing applications and smart contracts        |
| `Designer`  | Create beautiful and user-friendly interfaces         |
| `Marketer`  | Promote and grow communities and products             |
| `Founder`   | Lead and build innovative projects from the ground up |
| `BD`        | Drive partnerships and expand business opportunities  |
| `PM`        | Manage products and coordinate teams to deliver value |

> **Note**: Use `setAllowedRole("NewRole", true)` to add new roles.

---

## Allowed Social Keys

- `x`
- `farcaster`
- `website`
- `github`
- `linkedin`
- `basename`

> **Note**: Use `setAllowedSocialKey("newkey", true)` to add new social platforms.
