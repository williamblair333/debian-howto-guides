# Complete Claude Capabilities Guide
## With Practical Examples for Every Feature

*Generated January 2025 | For William's Work Reference*

---

## Table of Contents
1. [Model Selection Guide](#model-selection-guide)
2. [Official Anthropic Products](#official-anthropic-products)
3. [MCP Integrations](#mcp-integrations)
4. [IDE & Editor Integrations](#ide--editor-integrations)
5. [Cloud Platform Access](#cloud-platform-access)
6. [Automation Platforms](#automation-platforms)
7. [Advanced Capabilities](#advanced-capabilities)
8. [Usage Limits Reference](#usage-limits-reference)

---

## Model Selection Guide

### When to Use Opus 4.5

| Use Case | % | Example Prompt |
|----------|---|----------------|
| Complex multi-file refactoring | 15% | *"Refactor this 12-file Django app from function-based views to class-based views, maintaining all existing tests and adding type hints throughout."* |
| Novel architectural decisions | 12% | *"I'm building a permaculture planning system that needs to model plant guilds, succession planting, and nutrient cycling across 6 acres. Design the database schema and API structure."* |
| Deep research synthesis | 15% | *"Analyze these 8 academic papers on apophatic theology and synthesize them into a coherent framework I can use for my fiction writing system."* |
| Nuanced creative writing | 12% | *"Write chapter 3 of my novel using the apophatic fiction constraints: no direct naming of the divine, meaning emerges through absence, maintain the established prose rhythm from chapters 1-2."* |
| Debugging subtle bugs | 10% | *"This Python scraper works 95% of the time but occasionally returns None for prices that clearly exist on the page. Here's the code and 3 example failures..."* |
| Complex document analysis | 8% | *"Review this 40-page foreclosure property package. Identify all liens, easements, title issues, and calculate true acquisition cost including back taxes."* |
| Multi-step agentic workflows | 10% | *"Search for Indianapolis properties in bankruptcy, cross-reference with county tax records, filter for lots over 1 acre, and create a ranked spreadsheet by potential ROI."* |
| System design | 8% | *"Design a spaced repetition system that integrates with my custom practice problem websites and optimizes review intervals based on problem difficulty and my error patterns."* |
| Sustained voice/style | 5% | *"Continue this 15,000-word document maintaining the established academic tone, citation style, and argumentative structure."* |
| High-stakes outputs | 5% | *"Draft the executive summary for my investor pitch deck. This needs to convey our real estate investment thesis in exactly 200 words."* |

### When to Use Sonnet 4.5 (Your Daily Driver)

| Use Case | % | Example Prompt |
|----------|---|----------------|
| Daily coding tasks | 20% | *"Write a Python script that scrapes Newegg laptop listings and matches them against PassMark benchmark scores stored in a local SQLite database."* |
| Iterating on drafts | 15% | *"Here's my draft blog post about heavy metal bands with meaningful lyrics. Tighten the intro and add a section about Gojira."* |
| General Q&A | 15% | *"Explain the relationship between Gibbs free energy and spontaneous reactions. I'm working through gen chem foundations."* |
| Quick code reviews | 12% | *"Review this function for edge cases and potential bugs. Focus on the error handling."* |
| Web searches | 10% | *"What are the current VA loan limits for multi-unit properties in Indiana?"* |
| Content generation | 8% | *"Write a product description for a 5-acre rural property with restored VA loan eligibility appeal."* |
| Data analysis | 8% | *"Here's a CSV of 50 foreclosure properties. Add columns for price-per-acre and days-on-market, then sort by best value."* |
| Concept explanations | 5% | *"Explain Le Chatelier's principle using an analogy I'd understand as someone who gardens."* |
| Routine scripting | 5% | *"Write a bash script that backs up my /projects folder to an external drive daily at 2 AM."* |
| Troubleshooting | 2% | *"My n8n workflow isn't triggering. Here's the configuration—what am I missing?"* |

### When to Use Haiku 4.5 (API/Automation Focus)

| Use Case | % | Example Prompt |
|----------|---|----------------|
| High-volume API calls | 25% | *Batch processing 10,000 product descriptions for keyword extraction* |
| Classification/tagging | 20% | *"Classify this email: spam, newsletter, personal, or business"* |
| Quick factual lookups | 15% | *"What's the atomic number of carbon?"* |
| Data extraction | 12% | *"Extract the price, address, and square footage from this listing text."* |
| Chatbot responses | 10% | *Simple customer service FAQ responses* |
| Short summarization | 8% | *"Summarize this 200-word paragraph in one sentence."* |
| Simple completions | 5% | *"Complete this function that adds two numbers."* |
| Real-time applications | 3% | *Live typing suggestions, instant feedback loops* |
| Linting suggestions | 1% | *"Is this variable name following Python conventions?"* |
| Webhook processing | 1% | *Parsing incoming webhook payloads* |

---

## Official Anthropic Products

### Claude.ai (Web/Mobile/Desktop Chat)

**What it is:** The main consumer interface for interacting with Claude.

**Example workflow:**
```
You: I'm analyzing a foreclosure property at 1234 Oak Street, Indianapolis. 
     The listing shows $85,000 but mentions "back taxes owed." 
     Help me build a due diligence checklist.

Claude: Here's your due diligence checklist for 1234 Oak Street:

        □ Title Search
          - Request preliminary title report
          - Check for federal/state tax liens
          - Verify no mechanic's liens from recent work
        
        □ Tax Status
          - Contact Marion County Treasurer for exact back tax amount
          - Determine if tax sale is pending
          - Calculate penalties and interest
        
        □ Property Condition
          - Schedule inspection (budget $400-500)
          - Check for code violations with city
          - Verify utilities can be connected
        
        [continues with full checklist...]
```

---

### Claude Code (Terminal CLI)

**What it is:** An agentic coding assistant that runs in your terminal, can edit files, run tests, manage git, and execute multi-step tasks autonomously.

**Installation:**
```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Navigate to your project
cd ~/projects/newegg-scraper

# Start Claude Code
claude
```

**Example session:**
```
You: This scraper is missing prices for about 5% of laptops. 
     Debug the issue and fix it.

Claude: I'll analyze the scraper and identify the issue.

        ⏺ Reading scraper.py...
        ⏺ Found the issue: The price selector fails when items are 
          "Out of Stock" because the price element is replaced with 
          a "Notify Me" button.
        
        ⏺ Editing scraper.py...
        ⏺ Added fallback selector and "Out of Stock" detection
        ⏺ Running tests...
        
        ✓ All 23 tests passing
        ✓ Created commit: "Fix price extraction for out-of-stock items"
        
        The fix handles three cases:
        1. Normal price display
        2. Sale price (was/now format)  
        3. Out of stock (now returns None with status flag)
```

**Power features:**
```bash
# Run in headless mode for automation
claude --headless "Run all tests and fix any failures"

# Use with specific model
claude --model opus "Design the database schema for my permaculture app"

# Background task
claude --background "Keep the dev server running while I work"
```

---

### Claude Code VS Code Extension

**What it is:** Native IDE integration with inline diffs, sidebar panel, and visual change review.

**Installation:**
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search "Claude Code"
4. Install the official Anthropic extension

**Example workflow:**
```
1. Open your project in VS Code
2. Click the Claude icon in the sidebar
3. Type: "Add input validation to all API endpoints in /routes"
4. Claude shows inline diffs for each file
5. Review changes with green/red highlighting
6. Click "Accept" or "Reject" for each change
7. Claude automatically stages accepted changes
```

**Screenshot description:**
```
┌─────────────────────────────────────────────────────┐
│ CLAUDE CODE                               [Refresh] │
├─────────────────────────────────────────────────────┤
│ > Add input validation to all API endpoints         │
├─────────────────────────────────────────────────────┤
│ 📁 routes/users.js                                  │
│   + const { body, validationResult } = require(...) │
│   + body('email').isEmail().normalizeEmail(),       │
│                                      [Accept][Skip] │
├─────────────────────────────────────────────────────┤
│ 📁 routes/products.js                               │
│   + body('price').isFloat({ min: 0 }),              │
│                                      [Accept][Skip] │
└─────────────────────────────────────────────────────┘
```

---

### Claude Code JetBrains Extension

**What it is:** Same functionality as VS Code extension, for IntelliJ, PyCharm, WebStorm, etc.

**Installation:**
1. Open Settings → Plugins
2. Search "Claude Code"
3. Install and restart IDE

**Example use case:**
```
Working in PyCharm on your practice problem generator:

You: "Convert all these raw SQL queries to SQLAlchemy ORM calls"

Claude analyzes 15 files, shows diffs in the IDE's diff viewer,
you review each change in PyCharm's familiar interface.
```

---

### Claude for Chrome (Beta)

**What it is:** A browser agent that can navigate websites, fill forms, click buttons, and automate web tasks.

**Requirements:** Max plan subscription

**Example workflows:**

```
Prompt: "Check my Gmail for emails from Zillow in the last week, 
         summarize any new Indianapolis listings, and add them 
         to my 'Properties to Review' Google Sheet."

Claude:
  ⏺ Opening Gmail...
  ⏺ Searching for "from:zillow.com newer_than:7d"
  ⏺ Found 4 emails with listings
  ⏺ Opening Google Sheets...
  ⏺ Adding 4 new rows to 'Properties to Review'
  
  Summary:
  - 3847 Meridian St: $125,000, 3BR/2BA, foreclosure
  - 892 College Ave: $89,000, 2BR/1BA, estate sale
  - [continues...]
```

```
Prompt: "Go to the Marion County tax assessor site, look up 
         parcel 1234567, and download the tax history PDF."

Claude:
  ⏺ Navigating to indy.gov/assessor
  ⏺ Entering parcel number...
  ⏺ Clicking 'Tax History'
  ⏺ Downloading PDF...
  ⏺ Saved to ~/Downloads/parcel-1234567-tax-history.pdf
```

---

### Claude for Excel (Beta)

**What it is:** A spreadsheet agent that can read, analyze, and modify Excel files with thousands of rows.

**Example workflow:**
```
You have a 2,000-row spreadsheet of foreclosure listings.

Prompt: "Add a column that calculates price-per-square-foot, 
         flag any properties where that ratio is below $50 
         (potential deals), and create a pivot table summarizing 
         by zip code."

Claude:
  ⏺ Reading spreadsheet (2,147 rows)
  ⏺ Adding 'Price_Per_SqFt' column with formula
  ⏺ Adding 'Potential_Deal' flag column
  ⏺ Found 23 properties under $50/sqft
  ⏺ Creating pivot table on new sheet...
  
  Done. 23 potential deals flagged. Pivot table shows:
  - 46201: 8 deals (avg $42/sqft)
  - 46203: 6 deals (avg $47/sqft)
  - [continues...]
```

---

### Claude API

**What it is:** Programmatic access for building your own applications.

**Example Python integration:**
```python
import anthropic

client = anthropic.Anthropic()

# Simple completion
message = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "What's the optimal pH range for blueberries?"}
    ]
)
print(message.content[0].text)

# With tools
message = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=1024,
    tools=[{
        "name": "get_property_data",
        "description": "Fetch property data from county records",
        "input_schema": {
            "type": "object",
            "properties": {
                "parcel_id": {"type": "string"}
            },
            "required": ["parcel_id"]
        }
    }],
    messages=[
        {"role": "user", "content": "Look up parcel 49-12-34-567"}
    ]
)
```

**Pricing (pay-per-use):**
| Model | Input | Output |
|-------|-------|--------|
| Opus 4.5 | $15/MTok | $75/MTok |
| Sonnet 4.5 | $3/MTok | $15/MTok |
| Haiku 4.5 | $0.25/MTok | $1.25/MTok |

---

### Claude Desktop App

**What it is:** Native macOS/Windows application with MCP support for local integrations.

**Key advantage:** Can connect to local MCP servers for file system access, database connections, and custom tools.

**Example MCP configuration (claude_desktop_config.json):**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/william/projects"]
    },
    "sqlite": {
      "command": "npx", 
      "args": ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", "/home/william/data/properties.db"]
    }
  }
}
```

**Now Claude can:**
```
You: "Query my properties database for all listings under $100k 
      in Morgan County, then create a markdown report in my 
      projects folder."

Claude:
  ⏺ [Using sqlite tool] SELECT * FROM listings WHERE price < 100000 AND county = 'Morgan'
  ⏺ Found 7 properties
  ⏺ [Using filesystem tool] Creating /home/william/projects/morgan-county-report.md
  ⏺ Done. Report saved with property details, photos, and analysis.
```

---

### Claude iOS App

**What it is:** Mobile access to Claude, including ability to delegate Claude Code tasks remotely.

**Example mobile workflow:**
```
You're at a property showing and notice something in the code...

You (on phone): "In my newegg-scraper project, add support for 
                 filtering by screen size. Min 15 inches."

Claude Code (on your computer at home):
  ⏺ Opening /projects/newegg-scraper
  ⏺ Adding screen_size_min parameter
  ⏺ Updating CLI arguments
  ⏺ Adding filter logic
  ⏺ Tests passing
  ⏺ Committed: "Add screen size filtering"

You get a notification when it's done.
```

---

## MCP Integrations

### n8n MCP

**What it is:** Claude can build complete n8n workflows from a single prompt.

**Setup:**
```bash
# Install n8n-mcp
npx n8n-mcp

# Or use hosted version at n8n-mcp.com
```

**Example prompt:**
```
"Create an n8n workflow that:
1. Triggers daily at 8 AM
2. Scrapes Zillow for new Indianapolis foreclosures
3. Filters for properties under $150k
4. Adds matches to my Airtable 'Leads' table
5. Sends me a Slack summary"

Claude:
  ⏺ Analyzing requirements...
  ⏺ Building workflow with 6 nodes:
    - Schedule Trigger (daily 8 AM)
    - HTTP Request (Zillow API)
    - Filter node (price < 150000)
    - Airtable node (create records)
    - Slack node (send message)
    - Error handler
  ⏺ Workflow JSON generated
  ⏺ Direct import link: https://your-n8n.com/workflow/import?id=xxx
```

---

### Zapier MCP

**What it is:** Connect Claude to 8,000+ apps through Zapier's automation platform.

**Setup:**
1. Go to mcp.zapier.com
2. Create a server, select Claude as client
3. Add tools (Gmail, Airtable, Slack, etc.)
4. Copy the server URL to Claude's integrations

**Example prompt:**
```
"Check my Gmail for emails from county tax offices, 
 extract any mentioned deadlines, and add them to 
 my Google Calendar with 1-week advance reminders."

Claude:
  ⏺ [Zapier: Gmail] Searching for from:*county* tax
  ⏺ Found 3 emails with deadlines
  ⏺ [Zapier: Google Calendar] Creating events:
    - "Property tax deadline - Parcel 1234" - Jan 15
    - "Appeal deadline - 5678 Oak St" - Feb 1  
    - "Redemption period ends - 9012 Main" - Mar 30
  ⏺ All reminders set for 1 week prior
```

---

### Jira/Confluence Integration

**What it is:** Project management and documentation access.

**Example prompts:**
```
Jira: "Create a new epic called 'Permaculture App MVP' with 
       child stories for: database design, plant guild API, 
       succession planting calculator, and mobile UI."

Confluence: "Search our knowledge base for anything about 
             VA loan requirements and summarize the key points."
```

---

### Asana Integration

**What it is:** Task management automation.

**Example:**
```
"Look at my 'Property Research' project in Asana. 
 For any task that's been in 'Waiting for Info' for 
 more than 5 days, add a comment asking for status 
 and move it to 'Needs Follow-up'."
```

---

### Linear Integration

**What it is:** Issue tracking for software projects.

**Example:**
```
"Create a bug report in Linear: The practice problem 
 randomizer is showing the same question twice in a row. 
 Priority: medium. Label: algorithm-bug."
```

---

### Slack Integration

**What it is:** Messaging and channel automation.

**Example:**
```
"Search my Slack DMs with [realtor name] for any 
 property addresses mentioned in the last month 
 and compile them into a list."
```

---

### GitHub/GitLab Integration

**What it is:** Code repository management.

**Example:**
```
"Review all open PRs in my newegg-scraper repo. 
 For any that have been open more than a week 
 without review, add a comment asking for status."
```

---

### Google Drive/Docs Integration

**What it is:** Document and file management.

**Example:**
```
"Find my 'Investment Property Checklist' doc in Drive, 
 make a copy called '1234 Oak Street Checklist', and 
 fill in the address and asking price fields."
```

---

### Financial Integrations (PayPal, Square, Stripe, Plaid)

**Example:**
```
"Connect to my Plaid account and show me all transactions 
 over $500 from the last 30 days categorized by vendor."
```

---

### Custom MCP Servers

**What it is:** Build your own integrations in about 30 minutes.

**Example: Property Database MCP Server**
```python
# property_mcp_server.py
from mcp import MCPServer
import sqlite3

server = MCPServer("property-database")

@server.tool("search_properties")
def search_properties(county: str, max_price: int):
    """Search the local property database"""
    conn = sqlite3.connect('properties.db')
    cursor = conn.execute(
        "SELECT * FROM listings WHERE county = ? AND price <= ?",
        (county, max_price)
    )
    return cursor.fetchall()

@server.tool("add_property")
def add_property(address: str, price: int, notes: str):
    """Add a new property to track"""
    conn = sqlite3.connect('properties.db')
    conn.execute(
        "INSERT INTO listings (address, price, notes) VALUES (?, ?, ?)",
        (address, price, notes)
    )
    conn.commit()
    return {"status": "added"}

server.run()
```

**Now in Claude:**
```
"Search my property database for Morgan County under $100k"
"Add 5678 Rural Route 4 to my database, $75,000, noting 
 it needs well inspection"
```

---

## IDE & Editor Integrations

### Cursor

**What it is:** VS Code fork with deep Claude integration.

**Example workflow:**
```
1. Open project in Cursor
2. Press Cmd+K for inline edit
3. Type: "Add error handling for network failures"
4. Claude suggests changes inline
5. Tab to accept, Esc to reject
```

---

### Windsurf

**What it is:** AI-native IDE with Claude support.

**Best for:** Large codebase navigation, multi-file refactoring

---

### Cline (VS Code Extension)

**What it is:** Open-source Claude integration for VS Code using API.

**Setup:**
```
1. Install Cline from VS Code marketplace
2. Add your Anthropic API key
3. Select claude-sonnet-4-5-20250929 as model
```

**Example:**
```
Cline: "Explain what this function does"
[Highlight code, Cline provides explanation in sidebar]
```

---

### Zed

**What it is:** Fast, modern editor with Claude Code support.

**Example:**
```
# In Zed's command palette:
> Claude: Refactor selected code to use async/await
```

---

### Aider

**What it is:** Terminal-based pair programming with Claude.

**Example session:**
```bash
$ aider --model claude-3-5-sonnet

aider> Add a caching layer to the API responses

Aider will:
1. Analyze your codebase
2. Propose changes
3. Show diffs
4. Apply on your approval
5. Auto-commit with descriptive message
```

---

## Cloud Platform Access

### Amazon Bedrock

**What it is:** Run Claude within your AWS infrastructure.

**Benefits:**
- Data stays in your AWS account
- Use existing AWS billing
- Integrate with other AWS services

**Example:**
```python
import boto3

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

response = bedrock.invoke_model(
    modelId='anthropic.claude-3-5-sonnet-20241022-v2:0',
    body=json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": "Hello!"}]
    })
)
```

---

### Google Cloud Vertex AI

**What it is:** Run Claude within GCP infrastructure.

**Example:**
```python
from google.cloud import aiplatform

client = aiplatform.gapic.PredictionServiceClient()

response = client.predict(
    endpoint="projects/PROJECT/locations/us-central1/publishers/anthropic/models/claude-3-5-sonnet",
    instances=[{"content": "Hello!"}]
)
```

---

### Microsoft Azure AI

**What it is:** Claude in Azure (public preview).

**Setup:** Access via Azure AI Model Catalog, search for Anthropic publisher.

---

## Automation Platforms

### n8n (Self-Hosted)

**What it is:** Open-source workflow automation with Claude node.

**Example workflow: Daily Property Alert**
```
[Schedule Trigger: 8 AM]
        ↓
[HTTP Request: Zillow API]
        ↓
[Claude Node: "Analyze these listings. Flag any that 
              seem underpriced for the neighborhood."]
        ↓
[Filter: flagged = true]
        ↓
[Airtable: Add to Leads table]
        ↓
[Email: Send daily digest]
```

---

### Zapier

**What it is:** No-code automation connecting 8,000+ apps.

**Example Zap:**
```
Trigger: New email in Gmail matching "foreclosure"
Action 1: Claude - "Extract property address and asking price"
Action 2: Google Sheets - Add row with extracted data
Action 3: Slack - Send notification to #deals channel
```

---

### Make (formerly Integromat)

**What it is:** Visual automation builder with advanced logic.

**Example scenario:**
```
Watch Folder → Claude Analysis → Router
                                   ├→ Property Doc → Add to CRM
                                   ├→ Legal Doc → Forward to Attorney
                                   └→ Other → Archive
```

---

### Pipedream

**What it is:** Developer-focused workflow automation.

**Example:**
```javascript
export default defineComponent({
  async run({ steps, $ }) {
    const response = await $.anthropic.messages.create({
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 1024,
      messages: [{
        role: "user",
        content: `Analyze this property listing: ${steps.trigger.event.body}`
      }]
    });
    return response.content[0].text;
  }
});
```

---

## Advanced Capabilities

### Computer Use

**What it is:** Claude can control a desktop—click, type, navigate applications.

**Example:**
```
"Open the Marion County GIS website, search for parcel 1234567, 
 take a screenshot of the property map, and save it to my 
 Desktop as 'parcel-1234567-map.png'"

Claude:
  ⏺ Opening Chrome...
  ⏺ Navigating to maps.indy.gov
  ⏺ Clicking search field...
  ⏺ Typing parcel number...
  ⏺ Waiting for map to load...
  ⏺ Taking screenshot...
  ⏺ Saved to ~/Desktop/parcel-1234567-map.png
```

---

### Web Search (Built-in)

**What it is:** Real-time web access integrated into Claude.

**Example:**
```
"What are the current Indiana foreclosure redemption periods 
 and have there been any recent legislative changes?"

Claude searches, synthesizes multiple sources, provides 
current accurate information with citations.
```

---

### Deep Research

**What it is:** Multi-hour autonomous research producing comprehensive reports.

**Example:**
```
"Research the Indianapolis real estate market for 2024-2025. 
 Focus on: foreclosure trends, price-per-sqft by neighborhood, 
 investor activity levels, and upcoming development projects. 
 Produce a 10-page report with data visualizations."

Claude:
  ⏺ This will take approximately 2-3 hours
  ⏺ Beginning research...
  [Runs autonomously, searches dozens of sources]
  ⏺ Research complete. Report generated.
```

---

### File Creation

**What it is:** Generate DOCX, XLSX, PPTX, PDF files on demand.

**Examples:**
```
"Create a Word document with my property analysis for 1234 Oak Street"
→ Downloads: property-analysis-1234-oak.docx

"Build a spreadsheet comparing these 5 properties with formulas 
 for ROI calculation"
→ Downloads: property-comparison.xlsx

"Create a PowerPoint pitch deck for my real estate investment thesis"
→ Downloads: investment-pitch.pptx
```

---

### Code Execution

**What it is:** Run Python in a sandboxed environment.

**Example:**
```
"Calculate the compound interest on a $75,000 investment 
 at 8% over 10 years with monthly compounding. Show your work."

Claude:
  ⏺ Running Python...
  
  ```python
  principal = 75000
  rate = 0.08
  time = 10
  n = 12  # monthly
  
  amount = principal * (1 + rate/n)**(n*time)
  print(f"Final amount: ${amount:,.2f}")
  print(f"Interest earned: ${amount - principal:,.2f}")
  ```
  
  Output:
  Final amount: $165,854.25
  Interest earned: $90,854.25
```

---

### Memory

**What it is:** Claude remembers context across conversations.

**How it works for you:**
```
Claude already knows:
- You're a veteran with VA loan eligibility
- You own 5 acres worth ~$75k
- You earn $70k annually
- You're interested in Indianapolis foreclosures
- You're building a permaculture system for 21 people
- You're pursuing scientific literacy across multiple disciplines
- You enjoy heavy metal with meaningful lyrics
- You're developing "apophatic fiction" writing systems
- You play Pathfinder 1e and design custom archetypes

So when you ask: "What properties should I look at?"
Claude considers your VA loan status, income, existing land, 
and investment goals without you re-explaining.
```

---

### Subagents

**What it is:** Delegate parallel tasks to specialized sub-agents.

**Example:**
```
"Build my permaculture planning app MVP"

Claude:
  ⏺ Spawning subagents...
  
  [Subagent 1: Database] Designing plant guild schema...
  [Subagent 2: Backend] Building FastAPI endpoints...
  [Subagent 3: Frontend] Creating React components...
  
  All three work in parallel, main agent coordinates.
```

---

### Hooks

**What it is:** Auto-trigger actions at specific points.

**Example configuration (.claude/settings.json):**
```json
{
  "hooks": {
    "after_file_edit": "npm run test",
    "before_commit": "npm run lint",
    "on_error": "notify-send 'Claude hit an error'"
  }
}
```

---

### Checkpoints

**What it is:** Save code + conversation state, rewind if needed.

**Example:**
```
You: "Refactor the entire authentication system to use JWT"

Claude makes changes across 12 files...

You: "Actually, that broke too many things. Rewind."

⏺ /rewind
⏺ Select checkpoint: "Before auth refactor" 
⏺ Restored code state
⏺ Restored conversation context

Claude now remembers you tried JWT and it didn't work,
can suggest alternatives.
```

---

### Background Tasks

**What it is:** Keep processes running while Claude works on other things.

**Example:**
```
"Start the dev server and keep it running while you 
 implement the new search feature"

Claude:
  ⏺ [Background] npm run dev - running on localhost:3000
  ⏺ [Foreground] Implementing search feature...
  ⏺ [Foreground] Testing against running server...
  ⏺ [Foreground] Done. Server still running.
```

---

### Plugins

**What it is:** Install organizational workflows with one command.

**Example:**
```bash
# Install a company-wide code review plugin
claude plugins install @mycompany/code-review-standards

# Now Claude automatically:
# - Checks code against company style guide
# - Runs required security scans
# - Formats commit messages correctly
# - Adds required documentation
```

---

### Batch Processing (API)

**What it is:** Submit many requests efficiently, get results asynchronously.

**Example:**
```python
# Process 1000 property descriptions
batch = client.batches.create(
    requests=[
        {"custom_id": f"prop_{i}", "params": {
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 100,
            "messages": [{"role": "user", "content": f"Extract sqft from: {desc}"}]
        }}
        for i, desc in enumerate(property_descriptions)
    ]
)

# Check status, retrieve results when done
results = client.batches.retrieve(batch.id)
```

---

## Usage Limits Reference

### Max 5x Plan ($100/month)

| Resource | Per 5 Hours | Per Week |
|----------|-------------|----------|
| Chat messages | ~225 | ~7,500+ |
| Claude Code prompts | 50-200 | varies |
| Sonnet 4.5 hours | -- | 140-280 |
| Opus 4.5 hours | -- | 15-35 |

### Factors That Consume More Quota

- Long conversations (more context = more tokens)
- File attachments
- Large codebases in Claude Code
- Multiple parallel sessions
- Opus model usage (consumes faster than Sonnet)

### Tips for Maximizing Usage

1. **Start new conversations** for unrelated tasks (don't let context bloat)
2. **Use Sonnet for 85% of work** (save Opus for complex reasoning)
3. **Be specific** in prompts (reduces back-and-forth)
4. **Use Claude Code's /compact** command to summarize long sessions
5. **Batch similar tasks** rather than spreading throughout day

---

## Quick Reference Card

### Daily Workflow Recommendation

| Time | Task Type | Model | Interface |
|------|-----------|-------|-----------|
| Morning | Email triage, scheduling | Sonnet | Claude.ai + Zapier MCP |
| Mid-morning | Coding work | Sonnet | Claude Code / VS Code |
| Lunch | Property research | Sonnet | Claude.ai + Web Search |
| Afternoon | Complex analysis | Opus | Claude.ai |
| Evening | Documentation, planning | Sonnet | Claude.ai |

### Model Selection Cheat Sheet

```
Simple question? → Sonnet (or Haiku via API)
Coding task? → Sonnet in Claude Code
Multi-file refactor? → Opus in Claude Code
Creative writing? → Opus for quality, Sonnet for iteration
Research? → Sonnet with web search, or Deep Research for comprehensive
Quick automation? → Haiku via API
```

---

*Document generated by Claude Opus 4.5 | January 2025*
*For William | Real Estate Investment & Technical Projects*
