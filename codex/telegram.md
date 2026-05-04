# Telegram Bot Integration Guide for n8n Workflows

A complete guide to setting up Telegram notifications in n8n, from zero to working alerts.

---

## Prerequisites

- n8n instance (self-hosted or cloud)
- Smartphone or desktop with Telegram installed
- 10-15 minutes

---

## Part 1: Install Telegram

### Mobile (iOS/Android)
1. Download "Telegram" from App Store or Google Play
2. Open and sign up with your phone number
3. Verify via SMS code
4. Set your name and optional profile photo

### Desktop
1. Go to https://desktop.telegram.org
2. Download and install
3. Sign in with your phone number (you'll get a code in Telegram mobile if already installed)

---

## Part 2: Create a Telegram Bot

Bots are how external services (like n8n) send you messages. You create bots through Telegram's official "BotFather."

### Step-by-Step

1. **Open Telegram** and search for `@BotFather`
2. **Start a chat** with BotFather (click Start if prompted)
3. **Send the command:** `/newbot`
4. **Choose a display name** when prompted (e.g., "My Alerts Bot")
   - This is what you'll see in chats
5. **Choose a username** when prompted (e.g., "my_alerts_12345_bot")
   - Must end in "bot"
   - Must be unique across all of Telegram
6. **Save your bot token** - BotFather will reply with something like:
```
Done! Congratulations on your new bot. You will find it at t.me/my_alerts_12345_bot.

Use this token to access the HTTP API:
8389233291:AAHnLwYin742gdFyGA1P7Gfb4ilyo92xWls
```

⚠️ **Keep this token secret!** Anyone with it can control your bot.

---

## Part 3: Get Your Chat ID

Your Chat ID tells the bot WHERE to send messages (to you specifically).

### Method 1: Use a Bot

1. Search for `@userinfobot` in Telegram
2. Start a chat and send any message
3. It replies with your info including:
```
   Id: 7193373883
   First: YourName
```
4. Save that **Id number** - this is your Chat ID

### Method 2: Use the Telegram API

1. Send any message to YOUR new bot (search for its username, click Start)
2. Open this URL in a browser (replace YOUR_BOT_TOKEN):
```
   https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
```
3. Look for `"chat":{"id":XXXXXXXX}` in the response
4. That number is your Chat ID

---

## Part 4: Initialize the Bot

**Critical step that's often missed!**

Before your bot can message you, you must start a conversation with it:

1. Search for your bot by its username in Telegram
2. Click **Start** or send it any message ("hi" works)
3. This authorizes the bot to send you messages

Without this step, you'll get "chat not found" errors.

---

## Part 4.1: How to Revoke (Invalidate) a Bot Token

If a token is exposed, leaked, or stored insecurely, revoke it immediately. Revocation instantly disables the old token; any service using it (including n8n) will fail authentication until updated. :contentReference[oaicite:0]{index=0}

### Steps (via BotFather)

1. Open Telegram and search for `@BotFather`
2. Start chat if not already open
3. Send the command:
```
/mybots
```
4. Select your bot from the list
5. Tap **API Token**
6. Choose **Revoke current token**
7. BotFather will automatically generate a **new token**
8. Copy the new token and update it in **n8n → Credentials → Telegram API**
9. Save the credential and retest

---

### What Happens After Revocation

- Old token becomes permanently invalid
- Any system using the old token returns **401 Unauthorized**
- Bot settings, chat history, and configuration remain unchanged
- Only the authentication key is replaced

---

### Post-Revocation Checklist

- [ ] Token updated in n8n credentials
- [ ] Telegram node tested successfully
- [ ] Old token removed from notes, logs, and files
- [ ] Environment variables updated (if used)

Treat token revocation the same as rotating a compromised password.

---

## Part 5: Configure n8n Credentials

### Add Telegram Credential

1. Open your n8n instance
2. Go to **Credentials** (in left sidebar or via menu)
3. Click **Add Credential**
4. Search for **"Telegram API"**
5. Fill in:
   - **Access Token:** Your bot token from BotFather
```
     8389233291:AAHnLwYin742gdFyGA1P7Gfb4ilyo92xWls
```
   - **Base URL:** Leave as default (`https://api.telegram.org`)
6. Click **Save**
7. n8n will test the connection - should show success

### If "Couldn't connect" Error

- Double-check the token (no extra spaces)
- Make sure you copied the FULL token including the colon
- Try creating a new bot with BotFather if token seems corrupted

---

## Part 6: Use Telegram in a Workflow

### Add a Telegram Node

1. Open or create a workflow
2. Click **+** to add a node
3. Search for **Telegram**
4. Select **Telegram** node

### Configure the Node

1. **Credential:** Select the Telegram credential you created
2. **Resource:** Message
3. **Operation:** Send Message
4. **Chat ID:** Your chat ID (e.g., `7193373883`)
5. **Text:** Your message content
   - Can include dynamic data: `Price is now: {{ $json.price }}`
   - Supports basic formatting (see below)

### Message Formatting Options

Set **Parse Mode** under Additional Fields:

**Markdown:**
```
*bold text*
_italic text_
`inline code`
```

**HTML:**
```
<b>bold</b>
<i>italic</i>
<code>code</code>
```

---

## Part 7: Test Your Setup

### Quick Test Workflow

1. Create new workflow
2. Add **Manual Trigger** node
3. Add **Telegram** node connected to it
4. Configure Telegram node:
   - Credential: Your Telegram credential
   - Chat ID: Your chat ID
   - Text: `Test message from n8n!`
5. Click **Test Workflow**
6. Check Telegram - you should receive the message

---

## Troubleshooting

### "Chat not found" (Error 400)

**Cause:** Bot doesn't have permission to message you

**Fix:** 
1. Find your bot in Telegram
2. Click Start or send it a message
3. Try again

### "Unauthorized" (Error 401)

**Cause:** Invalid bot token

**Fix:**
1. Verify token is correct (no extra spaces)
2. Create new bot with BotFather if needed
3. Update credential in n8n

### "Couldn't connect with these settings"

**Cause:** Token format issue or network problem

**Fix:**
1. Token should look like: `1234567890:AAHxxxxxxxxxxxxxxxxxxxxxxx`
2. Must include the colon
3. Check your n8n instance has internet access

### Messages not arriving

**Check:**
1. Workflow is active (toggle in n8n)
2. Telegram notifications enabled on your device
3. Bot isn't muted in Telegram
4. Correct Chat ID (numbers only, no quotes)

### Rate Limits

Telegram limits bots to ~30 messages/second. For high-volume alerts:
- Batch messages where possible
- Add delays between sends
- Consider a group chat (higher limits)

---

## Quick Reference

| Item | Example | Where to Get |
|------|---------|--------------|
| Bot Token | `8389233291:AAHnLw...xWls` | @BotFather → /newbot |
| Chat ID | `7193373883` | @userinfobot |
| Bot Username | `@my_alerts_bot` | You choose during creation |

### Useful BotFather Commands

| Command | Purpose |
|---------|---------|
| `/newbot` | Create a new bot |
| `/mybots` | List your bots |
| `/setname` | Change bot's display name |
| `/setdescription` | Set bot description |
| `/deletebot` | Delete a bot |
| `/token` | Get/regenerate token |

---

## Security Best Practices

1. **Never share your bot token** - treat it like a password
2. **Store tokens in environment variables** - not in workflow JSON
3. **Regenerate token** if compromised (BotFather → /mybots → your bot → API Token → Revoke)
4. **Use dedicated bots** for different purposes (alerts, notifications, etc.)

---

## Group Chat Setup (Optional)

To send alerts to a group instead of yourself:

1. Create a Telegram group
2. Add your bot to the group
3. Send a message in the group
4. Get the group's Chat ID:
```
   https://api.telegram.org/botYOUR_TOKEN/getUpdates
```
   - Group IDs are negative numbers (e.g., `-1001234567890`)
5. Use that ID in your n8n Telegram node

---

## Summary Checklist

- [ ] Telegram installed and account created
- [ ] Bot created via @BotFather
- [ ] Bot token saved securely
- [ ] Chat ID obtained
- [ ] Sent "hi" to your bot (initialize it!)
- [ ] Credential added in n8n
- [ ] Test message received

Once complete, you can use Telegram notifications in any n8n workflow.
