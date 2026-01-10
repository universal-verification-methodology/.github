# AI-Powered README Generation

The `generate_readme.sh` script now supports AI-powered README generation, making it more dynamic and comprehensive by using AI to analyze repositories and generate intelligent, context-aware content.

## Features

### AI-Enhanced Content Generation

1. **Intelligent Overview & Description**
   - AI analyzes repository metadata (description, languages, topics)
   - Generates engaging, technical descriptions
   - Provides context about what the project does and why it's useful

2. **Smart Feature Detection**
   - AI generates 5-7 key features based on repository information
   - Features are specific and technical, not generic
   - Tailored to the actual repository content

3. **Usage Examples Generation**
   - AI generates practical code examples
   - Provides basic usage patterns
   - Includes explanations and common use cases
   - Format-aware (respects the project's primary language)

4. **Context-Aware Analysis**
   - Analyzes repository structure
   - Understands project organization
   - Generates relevant content based on actual repository content

## Configuration

### Basic Setup

Enable AI by setting environment variables:

```bash
export AI_ENABLED=true
export AI_PROVIDER=openai  # or 'anthropic', 'local'
export AI_API_KEY=your_api_key_here
export AI_MODEL=gpt-4o-mini  # or your preferred model
```

### Supported AI Providers

#### 1. OpenAI

```bash
export AI_ENABLED=true
export AI_PROVIDER=openai
export AI_API_KEY=sk-...
export AI_MODEL=gpt-4o-mini  # or gpt-4, gpt-3.5-turbo
```

#### 2. Anthropic (Claude)

```bash
export AI_ENABLED=true
export AI_PROVIDER=anthropic
export AI_API_KEY=sk-ant-...
export AI_MODEL=claude-3-haiku-20240307  # or claude-3-opus, claude-3-sonnet
```

#### 3. Cursor

Cursor uses OpenAI-compatible APIs and typically uses OpenAI models. This provider allows you to use Cursor's API endpoint or OpenAI directly with Cursor's configuration.

```bash
export AI_ENABLED=true
export AI_PROVIDER=cursor
export AI_API_KEY=sk-...  # Your OpenAI API key (Cursor uses OpenAI keys)
export AI_MODEL=gpt-4  # Cursor's default, or gpt-4o-mini, gpt-3.5-turbo
# Optional: Custom Cursor API endpoint
export CURSOR_API_URL=https://api.cursor.com/v1
```

**Note:** Cursor typically uses OpenAI models under the hood. If you're using Cursor IDE, you can use the same OpenAI API key. If Cursor has a custom API endpoint, set `CURSOR_API_URL`. Otherwise, it defaults to OpenAI's API.

#### 4. MCP (Model Context Protocol) with Cursor

MCP allows tools to provide rich context to AI models through resources and tools. This is particularly powerful with Cursor, as it can access repository files, documentation, and other resources.

```bash
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'
export MCP_RESOURCE_URI='file:///path/to/repository/README.md'  # Optional: specific resource
export MCP_TOOL_NAME='read_file'  # Optional: MCP tool to invoke
export MCP_FALLBACK_PROVIDER=openai  # Fallback if MCP only provides context
export AI_API_KEY=sk-...  # Required if using fallback provider
```

**MCP Modes:**

1. **MCP as Context Provider**: Use MCP to fetch repository context, then use regular AI provider
   ```bash
   export AI_PROVIDER=mcp
   export MCP_RESOURCE_URI='file:///path/to/repo/src/main.py'
   export MCP_FALLBACK_PROVIDER=openai
   export AI_API_KEY=sk-...
   ```

2. **MCP Tools**: Use MCP tools to generate content directly
   ```bash
   export AI_PROVIDER=mcp
   export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'
   export MCP_TOOL_NAME='generate_readme'
   ```

3. **MCP Resources**: Fetch resources and use them as context
   ```bash
   export AI_PROVIDER=mcp
   export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem'
   export MCP_RESOURCE_URI='file:///path/to/repo/docs/api.md'
   ```

**Popular MCP Servers:**
- `@modelcontextprotocol/server-filesystem` - File system access
- `@modelcontextprotocol/server-github` - GitHub API access
- `@modelcontextprotocol/server-postgres` - Database access
- Custom MCP servers for your specific needs

#### 5. Local Models (Ollama/OpenRouter)

```bash
export AI_ENABLED=true
export AI_PROVIDER=local
export AI_BASE_URL=http://localhost:11434/v1  # Ollama default
export AI_MODEL=llama2  # or mistral, codellama, etc.
# AI_API_KEY is optional for local models
```

### Advanced Configuration

```bash
# Custom base URL (for self-hosted or proxy)
export AI_BASE_URL=https://your-api-endpoint.com/v1

# Different model for different use cases
export AI_MODEL=gpt-4  # More capable but slower
export AI_MODEL=gpt-4o-mini  # Faster and cheaper
```

## Usage Examples

### Basic Usage with AI

```bash
# Enable AI
export AI_ENABLED=true
export AI_PROVIDER=openai
export AI_API_KEY=sk-...

# Generate README with AI
./generate_readme.sh owner repo-name
```

### Using Cursor

```bash
# Enable Cursor provider (uses OpenAI-compatible API)
export AI_ENABLED=true
export AI_PROVIDER=cursor
export AI_API_KEY=sk-...  # Your OpenAI API key
export AI_MODEL=gpt-4  # Cursor's default model

# Optional: If Cursor has a custom API endpoint
export CURSOR_API_URL=https://api.cursor.com/v1

# Generate README with Cursor
./generate_readme.sh owner repo-name
```

**Note:** Cursor uses OpenAI models, so you can use your OpenAI API key. If you're using Cursor IDE, check your Cursor settings for the API key being used.

### Using MCP (Model Context Protocol)

MCP allows you to provide rich context from various sources to enhance README generation.

#### Example 1: MCP with Filesystem Access

```bash
# Use MCP filesystem server to access repository files
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'
export MCP_RESOURCE_URI='file:///path/to/repo/src/main.py'
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-...

# Generate README with context from repository files
./generate_readme.sh owner repo-name
```

#### Example 2: MCP with GitHub Integration

```bash
# Use MCP GitHub server to fetch repository information
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-github'
export MCP_RESOURCE_URI='github://owner/repo/README.md'
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-...
export GITHUB_TOKEN=ghp_...

./generate_readme.sh owner repo-name
```

#### Example 3: MCP Tools for Direct Generation

```bash
# Use MCP tool to generate README directly
export AI_ENABLED=true
export AI_PROVIDER=mcp
export MCP_SERVER='npx -y @modelcontextprotocol/server-filesystem /path/to/repo'
export MCP_TOOL_NAME='generate_readme'

./generate_readme.sh owner repo-name
```

#### Example 4: MCP with Cursor IDE Integration

If you're using Cursor IDE with MCP servers configured:

```bash
# Cursor automatically provides MCP context
export AI_ENABLED=true
export AI_PROVIDER=mcp
# Cursor's MCP servers are automatically available
# You can specify which resource or tool to use
export MCP_RESOURCE_URI='cursor://workspace/README.md'
export MCP_FALLBACK_PROVIDER=openai
export AI_API_KEY=sk-...

./generate_readme.sh owner repo-name
```

### Using Local Models (Ollama)

```bash
# Start Ollama (if not running)
ollama serve

# Pull a model
ollama pull llama2

# Configure script
export AI_ENABLED=true
export AI_PROVIDER=local
export AI_BASE_URL=http://localhost:11434/v1
export AI_MODEL=llama2

# Generate README
./generate_readme.sh owner repo-name
```

### Batch Processing with AI

```bash
export AI_ENABLED=true
export AI_PROVIDER=openai
export AI_API_KEY=sk-...

# Generate READMEs for all repos in an organization
./generate_readme.sh owner --org ./output
```

## How It Works

### 1. Repository Analysis

The script collects:
- Repository description
- Primary and secondary languages
- Topics/tags
- Project structure
- Example files (if available)

### 2. AI Processing

The AI receives context about the repository and generates:
- **Overview**: Enhanced description explaining the project's purpose
- **Features**: Specific, technical features based on repository info
- **Usage**: Practical code examples and use cases

### 3. Fallback Behavior

If AI is unavailable or fails:
- Script falls back to template-based generation
- No errors are thrown
- README is still generated successfully

## Benefits

### Without AI
- Generic template-based content
- Static feature lists
- Placeholder usage examples
- Basic descriptions

### With AI
- **Dynamic, context-aware descriptions**
- **Repository-specific features**
- **Real, practical usage examples**
- **Intelligent analysis of project structure**
- **Better documentation quality**

### With MCP (Model Context Protocol)
- **Access to actual repository files** - Read source code, configs, docs
- **Real-time context** - Fetch latest information from various sources
- **Tool integration** - Use specialized tools for analysis and generation
- **Multi-source context** - Combine information from files, databases, APIs
- **Cursor IDE integration** - Seamlessly use Cursor's MCP servers
- **Extensible** - Add custom MCP servers for your specific needs

**MCP Use Cases:**
- Analyze actual source code files to generate accurate examples
- Fetch documentation from multiple sources
- Access database schemas for API documentation
- Use GitHub API through MCP for richer repository context
- Integrate with custom tools for domain-specific analysis

## Cost Considerations

### OpenAI
- `gpt-4o-mini`: ~$0.15 per 1M input tokens, ~$0.60 per 1M output tokens
- `gpt-4`: More expensive but higher quality
- Typical README generation: ~500-1000 tokens per repository

### Anthropic
- `claude-3-haiku`: Cost-effective for bulk operations
- `claude-3-opus`: Higher quality, higher cost

### Cursor
- Uses OpenAI models, so pricing is the same as OpenAI
- Typically defaults to `gpt-4` (more expensive)
- Can use `gpt-4o-mini` for cost savings
- If using Cursor's custom API, check Cursor's pricing

### MCP (Model Context Protocol)
- **MCP servers**: Usually free (open-source servers)
- **Context fetching**: No additional cost (just API calls to underlying provider)
- **Tool execution**: Depends on the tool (most are free)
- **Fallback provider**: Uses the same pricing as the fallback provider (OpenAI/Anthropic)

### Local Models
- **Free** - No API costs
- Requires local compute resources
- Best for privacy-sensitive environments

## Best Practices

1. **Use appropriate models**: `gpt-4o-mini` or `claude-3-haiku` for bulk operations
2. **Cache results**: AI-generated content can be cached to reduce API calls
3. **Review output**: Always review AI-generated content before committing
4. **Local models**: Use for sensitive repositories or high-volume operations
5. **Rate limiting**: Be mindful of API rate limits when processing many repositories
6. **MCP resources**: Use specific resource URIs to avoid fetching unnecessary context
7. **MCP tools**: Prefer tools over resources when you need active processing
8. **MCP fallback**: Always set a fallback provider when using MCP for context only

## Troubleshooting

### AI not generating content

1. Check API key is set correctly
2. Verify model name is correct for provider
3. Check network connectivity
4. Review API quota/limits

### Local models not working

1. Ensure Ollama is running: `ollama serve`
2. Verify model is pulled: `ollama list`
3. Check base URL: `http://localhost:11434/v1`
4. Test with: `curl http://localhost:11434/v1/models`

### MCP not working

1. **MCP Server Issues:**
   - Verify MCP_SERVER command is correct and executable
   - Test MCP server manually: `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | $MCP_SERVER`
   - Check MCP server logs for errors
   - Ensure required dependencies are installed (e.g., `npx` for npm-based servers)

2. **Resource URI Issues:**
   - Verify MCP_RESOURCE_URI format is correct (e.g., `file:///path/to/file`)
   - Check that the resource exists and is accessible
   - Ensure MCP server has permissions to access the resource

3. **Tool Issues:**
   - Verify MCP_TOOL_NAME matches an available tool
   - Check tool arguments format (must be valid JSON)
   - Review MCP server documentation for tool requirements

4. **Fallback Provider:**
   - If using MCP only for context, ensure MCP_FALLBACK_PROVIDER is set
   - Verify fallback provider API key is configured
   - Check that fallback provider is working independently

5. **Cursor IDE Integration:**
   - Ensure Cursor IDE is running with MCP servers configured
   - Check Cursor's MCP server configuration
   - Verify MCP resource URIs use `cursor://` prefix if needed

### Fallback to templates

If AI fails, the script automatically falls back to template-based generation. Check logs for AI-related warnings.

## Future Enhancements

Potential improvements:
- Analyze actual source code files for better examples
- Generate project-specific installation instructions
- Create architecture diagrams descriptions
- Generate API documentation from code
- Multi-language support for READMEs

## Security Notes

- **Never commit API keys** to version control
- Use environment variables or secret management
- For sensitive repositories, prefer local models
- Review AI-generated content before publishing
