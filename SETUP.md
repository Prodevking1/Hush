# Hush — Setup Guide

## API Key Configuration

Hush uses [OpenRouter](https://openrouter.ai/) for AI-powered text correction. Each user must provide their own API key.

The key is stored as XOR-obfuscated bytes in the source code to avoid plain text in the compiled binary. This is **not encryption** — it simply prevents casual string scanning.

### Step 1: Get your OpenRouter API key

1. Create an account at [openrouter.ai](https://openrouter.ai/)
2. Go to **Keys** and create a new API key
3. Copy the key (starts with `sk-or-v1-...`)

### Step 2: Encode your key with XOR

Run this in a terminal (requires Python 3):

```bash
python3 -c "
key = input('Paste your OpenRouter API key: ')
xor_byte = 0x5A
encoded = [hex(ord(c) ^ xor_byte) for c in key]
# Format as Swift UInt8 array
lines = []
for i in range(0, len(encoded), 13):
    chunk = ', '.join(encoded[i:i+13])
    lines.append(f'            {chunk},')
print()
print('Paste this into AppSettings.swift (bundledApiKey):')
print()
for line in lines:
    print(line)
"
```

### Step 3: Paste into the source code

Open `Sources/Hush/AppSettings.swift` and find:

```swift
private static let bundledApiKey: String = {
    let encoded: [UInt8] = [
        // Paste your XOR-0x5A encoded key here — see SETUP.md
    ]
```

Replace the comment with your encoded bytes:

```swift
private static let bundledApiKey: String = {
    let encoded: [UInt8] = [
        0x29, 0x31, 0x77, 0x35, ...  // your encoded bytes here
    ]
```

### Step 4: Build

```bash
swift build -c release
```

## License Server

The license server is a Cloudflare Worker deployed at `api.tryhush.app`. If you want to self-host:

1. `cd license-server`
2. `cp wrangler.toml.example wrangler.toml` (configure your own KV namespace)
3. Set secrets: `npx wrangler secret put STRIPE_SECRET_KEY`, `JWT_SECRET`, `STRIPE_WEBHOOK_SECRET`
4. `npx wrangler deploy`

## Requirements

- macOS 14+
- Swift 6.0+
- Accessibility permission (System Settings > Privacy > Accessibility)
