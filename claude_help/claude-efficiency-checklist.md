# Claude Usage Efficiency Checklist

## Before Starting a Conversation

- [ ] **Define your goal** — What specific outcome do you need?
- [ ] **Gather materials first** — Collect all files, code, or context before starting
- [ ] **Choose the right model** — Use Sonnet for most tasks; save Opus for complex reasoning
- [ ] **Disable unused features** — Turn off extended thinking, web search, or Research if not needed
- [ ] **Check if a Project fits** — Will you reference these materials again? Use a Project for caching

---

## During the Conversation

### Message Efficiency
- [ ] **Batch related questions** — Combine multiple questions into one message
- [ ] **Front-load context** — Provide environment, constraints, and background upfront
- [ ] **Don't re-upload files** — Reference previously uploaded files instead of uploading again
- [ ] **Send complete code blocks** — Include entire snippets, not fragments across messages

### Monitoring
- [ ] **Check usage at Settings > Usage** — Monitor your 5-hour session and weekly limits
- [ ] **Watch conversation length** — Longer threads = more tokens per message
- [ ] **At ~15-20 messages: Consider summarizing** — You're entering diminishing returns territory

---

## The Summary Handoff (Do This at 15-20 Messages)

When you've had a productive session and want to continue efficiently:

1. **Ask Claude:**
   > "Summarize our discussion in 200 words formatted as:
   > - Key decisions made
   > - Code patterns/solutions established  
   > - Current state of the work
   > - Next steps identified
   > 
   > Format this as context I can paste into a new chat."

2. **Start a new conversation**
3. **Paste the summary** as your opening message
4. **Continue working** with a fresh 200K token window

---

## Project Setup (For Recurring Work)

- [ ] **Create a Project** for any topic you'll revisit
- [ ] **Upload core documents** to Project Knowledge (they get cached)
- [ ] **Write concise Project Instructions** — General context only; task details go in chat
- [ ] **Clean up periodically** — Remove files you're no longer using

---

## Quick Reference: What Burns Tokens Fast

| High Token Cost | Lower Token Cost |
|-----------------|------------------|
| Long conversation history | Fresh conversations |
| Extended thinking enabled | Extended thinking off |
| Web search / Research active | Features disabled when unused |
| Re-uploading same files | Referencing cached files |
| Multiple short messages | Batched comprehensive messages |
| Opus model | Sonnet model |

---

## Daily Workflow Template

**Morning Block**
1. Start fresh chat
2. Front-load context for your main task
3. Work until ~15-20 messages
4. Generate summary → New chat

**Afternoon Block**
1. Paste morning summary (if continuing same work)
2. Or start fresh for new topic
3. Work until ~15-20 messages
4. Generate summary for tomorrow if needed

**End of Day**
- [ ] Save any critical summaries
- [ ] Note which Projects need cleanup
- [ ] Check weekly usage in Settings

---

## The Math

- One 50-message thread ≈ Five 10-message threads (in token cost)
- Summary compression: ~5,000 tokens → ~300 tokens (roughly 16x)
- Fresh chat + summary = Full context at fraction of the cost

---

*Tip: Ask Claude to remind you to summarize when conversations get long. This can be added to Claude's memory for automatic reminders.*
