# MCP (Model Context Protocol) Setup Guide

This guide will help you set up MCP servers for enhanced README generation with Cursor.

## What is MCP?

MCP (Model Context Protocol) allows AI tools to access external resources and tools, providing rich context for better README generation. With MCP, the script can:
- Read actual repository files
- Access GitHub API data
- Use specialized tools for analysis
- Integrate with Cursor IDE

## Prerequisites

1. **Node.js and npm** (for npm-based MCP servers)
   ```bash
   node --version  # Should be v18+
   npm --version
   ```

2. **Cursor IDE** (optional but recommended)
   - Cursor has built-in MCP support
   - MCP servers can be configured in Cursor settings

## Setting Up MCP Servers

### Option 1: Using Cursor IDE (Recommended)

Cursor IDE has built-in MCP support. To configure:

1. **Open Cursor Settings**
   - Press `Cmd/Ctrl + ,` to open settings
   - Search for "MCP" or "Model Context Protocol"

2. **Add MCP Server Configuration**

   Add this to your Cursor settings (usually in `~/.cursor/mcp.json` or Cursor settings):

   ```json
   {
     "mcpServers": {
       "filesystem": {
         "command": "npx",
         "args": [
           "-y",
           "@modelcontextprotocol/server-filesystem",
           "/path/to/your/workspace"
         ]
       },
       "github": {
         "command": "npx",
         "args": [
           "-y",
           "@modelcontextprotocol/server-github"
         ],
         "env": {
           "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token_here"
         }
       }
     }
   }
   ```

3. **Restart Cursor** after configuration

### Option 2: Standalone MCP Server Setup

For use with the `generate_readme.sh` script:

#### 1. Install MCP Filesystem Server

```bash
# Install globally (optional)
npm install -g @modelcontextprotocol/server-filesystem

# Or use npx (no installation needed)
npx -y @modelcontextprotocol/server-filesystem /path/to/repo
```

#### 2. Install MCP GitHub Server

```bash
# Install globally (optional)
npm install -g @modelcontextprotocol/server-github

# Or use npx
npx -y @modelcontextprotocol/server-github
```

#### 3. Set Up Environment Variables

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# MCP Configuration for README Generation
export AI_ENABLED=true
export AI_PROVIDER=mcp

# Filesystem MCP Server
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'

# GitHub MCP Server (alternative)
# export MCP_SERVER='npx -y @modelcontextprotocol/server-github'

# Fallback provider (required when MCP only provides context)
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-your-openai-key-here

# Optional: Specific resource or tool
# export MCP_RESOURCE_URI='file:///path/to/repo/README.md'
# export MCP_TOOL_NAME='read_file'
```

#### 4. Reload Shell Configuration

```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Popular MCP Servers for README Generation

### 1. Filesystem Server
**Purpose**: Read repository files for context

```bash
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'
```

**Use Cases**:
- Read source code files to generate accurate examples
- Access configuration files
- Read existing documentation

### 2. GitHub Server
**Purpose**: Access GitHub API for repository information

```bash
export MCP_SERVER='npx -y @modelcontextprotocol/server-github'
export GITHUB_TOKEN=ghp_your_token
```

**Use Cases**:
- Fetch repository metadata
- Access issues and PRs
- Get contributor information

### 3. Postgres Server (for database projects)
**Purpose**: Access database schemas

```bash
export MCP_SERVER='npx -y @modelcontextprotocol/server-postgres'
export POSTGRES_CONNECTION_STRING='postgresql://user:pass@host/db'
```

### 4. Custom MCP Server
You can create custom MCP servers for specific needs.

## Testing MCP Setup

### Test 1: Check MCP Server Availability

```bash
# Test filesystem server
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | \
  npx -y @modelcontextprotocol/server-filesystem /tmp
```

### Test 2: Test with README Generation Script

```bash
# Set up environment
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/test/repo'
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-your-key

# Test README generation
./scripts/generate_readme.sh owner repo-name
```

### Test 3: List Available MCP Resources

If using Cursor IDE, you can list available MCP resources through Cursor's MCP interface.

## Configuration Examples

### Example 1: Basic Filesystem Access

```bash
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /home/user/projects/my-repo'
export MCP_RESOURCE_URI='file:///home/user/projects/my-repo/src/main.py'
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-...
```

### Example 2: GitHub Integration

```bash
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-github'
export GITHUB_TOKEN=ghp_...
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-...
```

### Example 3: Multiple Context Sources

```bash
# Use MCP for context, OpenAI for generation
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'
export MCP_RESOURCE_URI='file:///path/to/repo/docs/api.md'
export MCP_FALLBACK_PROVIDER=openai
export AI_MODEL=gpt-4o-mini
export AI_API_KEY=sk-...
```

## Cursor IDE Integration

### Setting Up MCP in Cursor

1. **Open Cursor Settings**
   - `Cmd/Ctrl + Shift + P` → "Preferences: Open Settings (JSON)"

2. **Add MCP Configuration**

   ```json
   {
     "mcp": {
       "servers": {
         "filesystem": {
           "command": "npx",
           "args": [
             "-y",
             "@modelcontextprotocol/server-filesystem",
             "${workspaceFolder}"
           ]
         },
         "github": {
           "command": "npx",
           "args": [
             "-y",
             "@modelcontextprotocol/server-github"
           ],
           "env": {
             "GITHUB_PERSONAL_ACCESS_TOKEN": "your_token"
           }
         }
       }
     }
   }
   ```

3. **Restart Cursor**

4. **Verify MCP Servers**
   - Check Cursor's MCP status in the status bar
   - Or use Cursor's command palette: "MCP: List Servers"

## Troubleshooting

### MCP Server Not Starting

1. **Check Node.js version**
   ```bash
   node --version  # Should be v18+
   ```

2. **Verify npx is available**
   ```bash
   which npx
   npx --version
   ```

3. **Test MCP server manually**
   ```bash
   npx -y @modelcontextprotocol/server-filesystem /tmp
   ```

### Resource URI Not Found

1. **Check file path format**
   - Use absolute paths: `file:///absolute/path/to/file`
   - Ensure file exists and is readable

2. **Verify MCP server has access**
   - Check file permissions
   - Ensure MCP server is running in correct directory

### Cursor IDE Not Showing MCP

1. **Check Cursor version**
   - MCP support requires Cursor 0.30+ (approximately)

2. **Verify configuration**
   - Check settings JSON syntax
   - Ensure MCP servers are properly configured

3. **Restart Cursor**
   - Sometimes a restart is needed after configuration

## Next Steps

1. **Choose an MCP server** based on your needs
2. **Configure environment variables** for the script
3. **Test with a sample repository**
4. **Integrate with Cursor IDE** (optional but recommended)

## Additional Resources

- [MCP Documentation](https://modelcontextprotocol.io/)
- [MCP Servers List](https://github.com/modelcontextprotocol/servers)
- [Cursor MCP Guide](https://docs.cursor.com/mcp)

## Quick Start Script

Save this as `setup_mcp.sh`:

```bash
#!/bin/bash

echo "Setting up MCP for README generation..."

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required. Please install Node.js 18+"
    exit 1
fi

# Test MCP servers
echo "Testing MCP filesystem server..."
npx -y @modelcontextprotocol/server-filesystem --help &> /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Filesystem MCP server available"
else
    echo "✗ Filesystem MCP server not available"
fi

echo "Testing MCP GitHub server..."
npx -y @modelcontextprotocol/server-github --help &> /dev/null
if [ $? -eq 0 ]; then
    echo "✓ GitHub MCP server available"
else
    echo "✗ GitHub MCP server not available"
fi

# Create example configuration
cat > ~/.mcp_readme_config.sh << 'EOF'
# MCP Configuration for README Generation
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'
export MCP_FALLBACK_PROVIDER=openai
# export AI_API_KEY=sk-your-key-here
# export MCP_RESOURCE_URI='file:///path/to/resource'
EOF

echo ""
echo "✓ Configuration template created at ~/.mcp_readme_config.sh"
echo "Edit this file and add your API keys, then source it:"
echo "  source ~/.mcp_readme_config.sh"
```

Make it executable and run:
```bash
chmod +x setup_mcp.sh
./setup_mcp.sh
```
