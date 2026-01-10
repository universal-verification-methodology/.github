# Using Cursor's Built-in AI Agent (No API Key Required!)

Great news! You can use Cursor IDE's built-in AI agent for README generation **without needing an OpenAI API key**. This guide shows you how.

## What is Cursor Agent?

Cursor Agent is Cursor IDE's built-in AI that:
- ✅ **No API key required** - Uses Cursor's AI infrastructure
- ✅ **Free to use** - Included with Cursor IDE
- ✅ **MCP integration** - Works with Cursor's MCP servers
- ✅ **Context-aware** - Has access to your workspace files

## Quick Start

### Step 1: Ensure Cursor IDE is Running

Make sure Cursor IDE is open and running. The agent uses Cursor's MCP servers which are available when Cursor is active.

### Step 2: Configure the Script

```bash
# Enable AI
export AI_ENABLED=true

# Use Cursor's built-in agent (NO API KEY NEEDED!)
export AI_PROVIDER=cursor-agent

# Optional: Configure how to access Cursor's AI
export CURSOR_AGENT_MODE=mcp  # Use MCP servers (recommended)
```

### Step 3: Generate README

```bash
./scripts/generate_readme.sh owner repo-name
```

That's it! No API keys needed.

## How It Works

### Option 1: MCP Mode (Recommended)

When `CURSOR_AGENT_MODE=mcp`, the script:
1. Connects to Cursor's MCP servers (available when Cursor IDE is running)
2. Uses MCP to access repository context
3. Generates README content using Cursor's AI

**Requirements:**
- Cursor IDE must be running
- MCP servers should be enabled in Cursor (usually enabled by default)

### Option 2: Internal Mode

When `CURSOR_AGENT_MODE=internal`, the script attempts to use Cursor's internal API directly. This is still being developed.

## Configuration Examples

### Basic Usage

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent

./scripts/generate_readme.sh owner repo-name
```

### With MCP Resources

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent
export CURSOR_AGENT_MODE=mcp
export MCP_RESOURCE_URI='file:///path/to/repo/src/main.py'

./scripts/generate_readme.sh owner repo-name
```

### With Custom MCP Server

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'

./scripts/generate_readme.sh owner repo-name
```

## Troubleshooting

### "Cursor agent not available"

**Solution 1:** Make sure Cursor IDE is running
```bash
# Check if Cursor is running
ps aux | grep -i cursor
```

**Solution 2:** Enable MCP in Cursor
- Open Cursor Settings (`Cmd/Ctrl + ,`)
- Search for "MCP" or "Model Context Protocol"
- Ensure MCP servers are enabled

**Solution 3:** Configure MCP server manually
```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'
```

### "MCP server not found"

If Cursor's MCP servers aren't available, you can use a standalone MCP server:

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'
export MCP_FALLBACK_PROVIDER=openai  # Fallback if MCP fails
export AI_API_KEY=sk-...  # Only needed as fallback
```

## Comparison: cursor-agent vs Other Providers

| Feature | cursor-agent | openai | anthropic | local |
|---------|--------------|--------|-----------|-------|
| API Key Required | ❌ No | ✅ Yes | ✅ Yes | ❌ No |
| Cost | ✅ Free | 💰 Paid | 💰 Paid | ✅ Free |
| Cursor Integration | ✅ Native | ❌ No | ❌ No | ❌ No |
| MCP Support | ✅ Yes | ❌ No | ❌ No | ⚠️ Limited |
| Workspace Context | ✅ Yes | ❌ No | ❌ No | ❌ No |

## Benefits of Using Cursor Agent

1. **No API Costs** - Completely free
2. **No API Keys** - No need to manage keys
3. **Workspace Aware** - Has access to your files through Cursor
4. **MCP Integration** - Works seamlessly with MCP servers
5. **Privacy** - Processing happens through Cursor's infrastructure

## When to Use Cursor Agent

✅ **Use cursor-agent when:**
- You have Cursor IDE installed and running
- You want to avoid API costs
- You want workspace context awareness
- You're working within Cursor IDE

❌ **Use other providers when:**
- Cursor IDE is not available
- You need specific model features
- You're running in CI/CD without Cursor
- You need higher rate limits

## Advanced Usage

### Combining with MCP Resources

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent
export MCP_RESOURCE_URI='file:///path/to/repo/docs/api.md'
export CURSOR_AGENT_MODE=mcp

./scripts/generate_readme.sh owner repo-name
```

### Using with Cursor's MCP Tools

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor-agent
export MCP_TOOL_NAME='analyze_repository'
export CURSOR_AGENT_MODE=mcp

./scripts/generate_readme.sh owner repo-name
```

## Next Steps

1. **Try it out:**
   ```bash
   export AI_ENABLED=true
   export AI_PROVIDER=cursor-agent
   ./scripts/generate_readme.sh owner repo-name
   ```

2. **Configure MCP** (optional but recommended):
   - See `scripts/MCP_SETUP.md` for MCP server setup
   - Configure Cursor's MCP servers in Cursor settings

3. **Customize** (optional):
   - Set `CURSOR_AGENT_MODE` to control how Cursor AI is accessed
   - Configure MCP resources for richer context

## See Also

- `scripts/AI_README_GENERATION.md` - General AI usage guide
- `scripts/MCP_SETUP.md` - MCP server setup guide
- `scripts/generate_readme.sh` - Main script documentation
