# Scripts Documentation

This document describes all scripts in the `scripts/` directory, their functions, and how they work together in the workflow.

## Table of Contents

- [Script Categories](#script-categories)
- [Core Scripts](#core-scripts) ⭐ Required
- [Setup Scripts](#setup-scripts) 🔧 Required for Initial Setup
- [Integration Scripts](#integration-scripts) 🔗 Optional
- [Utility Scripts](#utility-scripts) 🛠️ Optional
- [Test Scripts](#test-scripts) 🧪 Optional
- [Workflow Overview](#workflow-overview)

---

## Script Categories

### Required Scripts (Core Functionality)
These scripts are essential for the main workflow:
- `generate_readme.sh` - Main script for README generation
- `search_repos.sh` - Search for GitHub repositories
- `fork_repos.sh` - Fork repositories to organization
- `push_readme.sh` - Push README files to GitHub

### Required for Initial Setup
These scripts are needed for first-time setup:
- `configure_cursor_ai.sh` - Configure AI provider settings
- `complete_setup.sh` - Complete automated setup
- `setup_mcp.sh` - Setup MCP (Model Context Protocol) integration
- `setup_cursor_mcp.sh` - Setup Cursor IDE MCP configuration

### Optional Scripts (Enhanced Features)
These scripts add additional functionality:
- `integrate_cursor_ai.sh` - Integrate Cursor IDE AI-generated content
- `integrate_cursor_ai_simple.sh` - Simple Cursor AI integration
- `use_cursor_manual.sh` - Use manually generated Cursor content
- `use_cursor_ai.sh` - Configure Cursor's internal AI API
- `check_cursor_ide.sh` - Check Cursor IDE status and MCP accessibility

### Utility Scripts (Maintenance/Troubleshooting)
These scripts help with maintenance and troubleshooting:
- `fix_mcp_cursor.sh` - Fix MCP Cursor + Ollama integration issues
- `fix_mcp_config.sh` - Fix MCP configuration file
- `fix_npm_path.sh` - Fix npm PATH to use nvm's npm
- `upgrade_nodejs.sh` - Upgrade Node.js to version 18+
- `use_node18.sh` - Switch to Node.js 18 using nvm
- `sort_repos_by_stars.sh` - Sort repos_to_fork.txt by stars
- `setup_summary.sh` - Quick setup status summary

### Test Scripts (Testing/Debugging)
These scripts are for testing and debugging:
- `test_cursor_mcp.sh` - Test MCP Cursor + Ollama integration
- `test_cursor_agent.sh` - Test Cursor Agent setup
- `test_cursor_detection.sh` - Test Cursor IDE detection
- `test_ollama.sh` - Test Ollama API

---

## Core Scripts

### `search_repos.sh` ⭐ **REQUIRED**
**Purpose**: Search GitHub for repositories matching criteria and identify repos not yet forked to the organization.

**Features**:
- Searches GitHub with custom queries
- Compares with existing organization repos
- Outputs repos that need to be forked
- Parallel processing (up to 10 concurrent jobs)
- Optional README-only filtering
- Sorts results by stars (descending)

**Usage**:
```bash
./scripts/search_repos.sh <search_query> [github_token] [--readme-only]
```

**Example**:
```bash
./scripts/search_repos.sh "language:systemverilog uvm"
./scripts/search_repos.sh "language:systemverilog uvm" ghp_xxx --readme-only
```

**Output**: `repos_to_fork.txt` (pipe-separated format)

**Status**: ⭐ **CORE** - Required for repository discovery

---

### `fork_repos.sh` ⭐ **REQUIRED**
**Purpose**: Fork multiple GitHub repositories to the universal-verification-methodology organization.

**Features**:
- Reads repos from `repos_to_fork.txt`
- Forks repositories via GitHub API
- Handles name conflicts (creates and imports)
- Comprehensive logging
- Error handling and retry logic

**Usage**:
```bash
./scripts/fork_repos.sh [repos_file] [github_token]
```

**Example**:
```bash
./scripts/fork_repos.sh repos_to_fork.txt ghp_xxxxxxxxxxxxx
```

**Output**: 
- `fork_log.txt` - Detailed log of operations
- `failed_forks.txt` - List of failed forks

**Status**: ⭐ **CORE** - Required for repository management

---

### `push_readme.sh` ⭐ **REQUIRED**
**Purpose**: Push README.md files to GitHub repositories using the GitHub API without cloning locally.

**Features**:
- Creates or updates README.md via GitHub API
- Handles both new and existing files (uses SHA for updates)
- Supports custom commit messages
- Can process single repos or entire directories

**Usage**:
```bash
# Single repository
./scripts/push_readme.sh owner repo_name [readme_file] [branch] [commit_message]

# All repos in directory
./scripts/push_readme.sh owner --org [readme_dir] [branch] [commit_message]
```

**Example**:
```bash
./scripts/push_readme.sh universal-verification-methodology cocotb README-cocotb.md
```

**Status**: ⭐ **CORE** - Required for README deployment

---


### `generate_readme.sh` ⭐ **REQUIRED**
**Purpose**: Main script for generating comprehensive README.md files for GitHub repositories using the GitHub API.

**Features**:
- Fetches repository metadata from GitHub API
- Generates structured README with badges, TOC, and sections
- Supports AI-powered content generation (optional)
- Multiple AI provider support (OpenAI, Anthropic, Ollama, Cursor, MCP)
- Can process single repos or entire organizations

**Usage**:
```bash
# Single repository
./scripts/generate_readme.sh owner repo-name [output_file] [branch]

# All repos in organization
./scripts/generate_readme.sh owner --org [output_dir] [branch]
```

**Example**:
```bash
./scripts/generate_readme.sh universal-verification-methodology cocotb
```

**AI Configuration**:
Requires `configure_cursor_ai.sh` or manual environment variable setup.

**Status**: ⭐ **CORE** - Required for main functionality

---

## Setup Scripts

### `configure_cursor_ai.sh` 🔧 **REQUIRED FOR AI FEATURES**
**Purpose**: Configure AI provider settings for README generation (no external API key needed).

**Features**:
- Creates configuration file at `~/.config/cursor-readme/config.sh`
- Configures Cursor Agent mode (uses Cursor IDE's built-in AI)
- Sets up MCP server configuration
- Configures Ollama as fallback
- Auto-detects available Ollama models

**Usage**:
```bash
./scripts/configure_cursor_ai.sh
```

**Output**: `~/.config/cursor-readme/config.sh`

**Status**: 🔧 **REQUIRED** for AI-powered README generation

---

### `complete_setup.sh` 🔧 **RECOMMENDED FOR FIRST-TIME SETUP**
**Purpose**: Complete automated setup for MCP Cursor + Ollama integration.

**Features**:
- Checks and fixes Node.js version (requires 18+)
- Tests Ollama installation and availability
- Configures MCP servers
- Creates configuration files
- Verifies all components

**Usage**:
```bash
./scripts/complete_setup.sh
```

**Dependencies**:
- Node.js 18+ (installs if nvm available)
- Ollama (checks if running)
- npm/npx

**Status**: 🔧 **RECOMMENDED** for first-time setup

---

### `setup_mcp.sh` 🔧 **OPTIONAL FOR MCP INTEGRATION**
**Purpose**: Setup MCP (Model Context Protocol) integration for README generation.

**Features**:
- Checks Node.js and npx prerequisites
- Tests MCP server availability
- Creates MCP configuration
- Configures filesystem and GitHub MCP servers

**Usage**:
```bash
./scripts/setup_mcp.sh
```

**Output**: `~/.config/mcp-readme/config.sh`

**Status**: 🔧 **OPTIONAL** - Only needed if using MCP provider

---

### `setup_cursor_mcp.sh` 🔧 **OPTIONAL FOR CURSOR MCP**
**Purpose**: Setup Cursor IDE MCP configuration in Cursor IDE settings.

**Features**:
- Detects Cursor IDE configuration directory
- Creates `mcp.json` configuration file
- Configures filesystem and GitHub MCP servers
- Provides setup instructions

**Usage**:
```bash
./scripts/setup_cursor_mcp.sh
```

**Output**: `~/.config/Cursor/User/mcp.json` (or `~/.cursor/mcp.json`)

**Status**: 🔧 **OPTIONAL** - Only needed if using Cursor IDE MCP

---

## Integration Scripts

### `use_cursor_manual.sh` 🔗 **OPTIONAL**
**Purpose**: Helper script to use Cursor IDE manually generated content with `generate_readme.sh`.

**Features**:
- Parses Cursor-generated content from file or stdin
- Extracts DESCRIPTION, FEATURES, USAGE_EXAMPLE, EXPLANATION sections
- Exports as environment variables
- Calls `generate_readme.sh` with parsed content

**Usage**:
```bash
# With file
./scripts/use_cursor_manual.sh owner repo-name cursor-content.txt

# Interactive (paste content)
./scripts/use_cursor_manual.sh owner repo-name
```

**Status**: 🔗 **OPTIONAL** - For manual Cursor IDE integration

---

### `integrate_cursor_ai.sh` 🔗 **OPTIONAL**
**Purpose**: Integration script to process Cursor IDE AI-generated content and merge with README generation.

**Features**:
- Parses Cursor-generated content
- Extracts structured sections
- Merges with base README structure
- Saves parsed content for reference

**Usage**:
```bash
./scripts/integrate_cursor_ai.sh owner repo-name cursor-generated-content.txt [output_file]
```

**Status**: 🔗 **OPTIONAL** - Alternative integration method (more complex)

---

### `integrate_cursor_ai_simple.sh` 🔗 **OPTIONAL**
**Purpose**: Simple script to integrate Cursor IDE AI-generated content with README generation.

**Features**:
- Simplified parsing of Cursor content
- Direct merging with README structure
- Less complex than `integrate_cursor_ai.sh`

**Usage**:
```bash
./scripts/integrate_cursor_ai_simple.sh owner repo-name cursor-content.txt [output_file]
```

**Status**: 🔗 **OPTIONAL** - Simpler alternative to `integrate_cursor_ai.sh`

---

### `use_cursor_ai.sh` 🔗 **OPTIONAL**
**Purpose**: Configure to use Cursor's internal AI API (if available).

**Features**:
- Updates configuration to use Cursor internal API
- Configures CURSOR_AGENT_MODE=internal
- Provides testing instructions

**Usage**:
```bash
./scripts/use_cursor_ai.sh
```

**Status**: 🔗 **OPTIONAL** - Alternative AI configuration

---

### `check_cursor_ide.sh` 🔗 **OPTIONAL**
**Purpose**: Check if Cursor IDE is running and MCP is accessible.

**Features**:
- Checks Cursor IDE process (WSL and native Linux support)
- Checks MCP server accessibility
- Verifies configuration files
- Tests API endpoints
- Provides status summary

**Usage**:
```bash
./scripts/check_cursor_ide.sh
```

**Status**: 🔗 **OPTIONAL** - Useful for troubleshooting

---

## Utility Scripts

### `fix_mcp_cursor.sh` 🛠️ **OPTIONAL**
**Purpose**: Fix script to ensure MCP Cursor + Ollama works correctly.

**Features**:
- Tests Ollama directly
- Updates configuration to use direct Ollama
- Fixes common configuration issues

**Usage**:
```bash
./scripts/fix_mcp_cursor.sh
```

**Status**: 🛠️ **OPTIONAL** - For troubleshooting MCP issues

---

### `fix_mcp_config.sh` 🛠️ **OPTIONAL**
**Purpose**: Fix MCP configuration file with correct settings.

**Features**:
- Recreates `~/.config/mcp-readme/config.sh` with correct settings
- Ensures Node.js 18 is used
- Sets up cursor-agent mode

**Usage**:
```bash
./scripts/fix_mcp_config.sh
```

**Status**: 🛠️ **OPTIONAL** - For fixing broken MCP config

---

### `fix_npm_path.sh` 🛠️ **OPTIONAL**
**Purpose**: Fix npm PATH to use nvm's npm instead of system npm.

**Features**:
- Updates ~/.bashrc with nvm configuration
- Ensures correct npm/npx paths
- Switches to Node.js 18

**Usage**:
```bash
./scripts/fix_npm_path.sh
```

**Status**: 🛠️ **OPTIONAL** - For npm/npx path issues

---

### `upgrade_nodejs.sh` 🛠️ **OPTIONAL**
**Purpose**: Upgrade Node.js to version 18+ for MCP compatibility.

**Features**:
- Installs nvm if not available
- Installs Node.js 18 LTS
- Sets Node.js 18 as default
- Tests MCP server compatibility

**Usage**:
```bash
./scripts/upgrade_nodejs.sh
```

**Status**: 🛠️ **OPTIONAL** - For Node.js version issues

---

### `use_node18.sh` 🛠️ **OPTIONAL**
**Purpose**: Switch to Node.js 18 using nvm (if already installed).

**Features**:
- Switches to Node.js 18 via nvm
- Sets as default version
- Updates ~/.bashrc if needed

**Usage**:
```bash
./scripts/use_node18.sh
```

**Status**: 🛠️ **OPTIONAL** - For quick Node.js 18 switching

---

### `sort_repos_by_stars.sh` 🛠️ **OPTIONAL**
**Purpose**: Sort `repos_to_fork.txt` by stars (highest first).

**Features**:
- Handles both old (5 fields) and new (13 fields) formats
- Preserves header row
- Sorts by stars field

**Usage**:
```bash
./scripts/sort_repos_by_stars.sh
```

**Status**: 🛠️ **OPTIONAL** - For organizing repository lists

---

### `setup_summary.sh` 🛠️ **OPTIONAL**
**Purpose**: Quick setup status summary.

**Features**:
- Shows Node.js version
- Shows Ollama status
- Lists available models
- Checks configuration file existence

**Usage**:
```bash
./scripts/setup_summary.sh
```

**Status**: 🛠️ **OPTIONAL** - For quick status check

---

## Test Scripts

### `test_cursor_mcp.sh` 🧪 **OPTIONAL**
**Purpose**: Test MCP Cursor + Ollama integration.

**Features**:
- Tests Ollama availability
- Tests direct Ollama API calls
- Tests ai_call function
- Tests cursor-agent → Ollama flow

**Usage**:
```bash
./scripts/test_cursor_mcp.sh
```

**Status**: 🧪 **OPTIONAL** - For testing integration

---

### `test_cursor_agent.sh` 🧪 **OPTIONAL**
**Purpose**: Test Cursor Agent setup for README generation.

**Features**:
- Checks Node.js version
- Verifies configuration
- Tests MCP server configuration
- Provides setup summary

**Usage**:
```bash
./scripts/test_cursor_agent.sh
```

**Status**: 🧪 **OPTIONAL** - For testing Cursor Agent

---

### `test_cursor_detection.sh` 🧪 **OPTIONAL**
**Purpose**: Quick test to verify Cursor IDE detection.

**Features**:
- Tests check_cursor_ide.sh
- Tests complete_setup.sh Cursor check
- Direct process check

**Usage**:
```bash
./scripts/test_cursor_detection.sh
```

**Status**: 🧪 **OPTIONAL** - For testing Cursor detection

---

### `test_ollama.sh` 🧪 **OPTIONAL**
**Purpose**: Test script to debug Ollama API calls.

**Features**:
- Checks Ollama status
- Lists available models
- Tests Ollama API call
- Tests jq parsing

**Usage**:
```bash
./scripts/test_ollama.sh
```

**Status**: 🧪 **OPTIONAL** - For debugging Ollama

---

## Workflow Overview

### Standard Workflow (Without AI)

1. **Search for repositories**:
   ```bash
   ./scripts/search_repos.sh "language:systemverilog uvm"
   ```

2. **Fork repositories** (optional):
   ```bash
   ./scripts/fork_repos.sh repos_to_fork.txt
   ```

3. **Generate READMEs**:
   ```bash
   ./scripts/generate_readme.sh owner repo-name
   ```

4. **Push READMEs** (optional):
   ```bash
   ./scripts/push_readme.sh owner repo-name README.md
   ```

### Workflow with AI (Recommended)

1. **Initial Setup** (one-time):
   ```bash
   # Complete setup
   ./scripts/complete_setup.sh
   
   # Or manual setup
   ./scripts/configure_cursor_ai.sh
   source ~/.config/cursor-readme/config.sh
   ```

2. **Search and Fork** (same as above)

3. **Generate READMEs with AI**:
   ```bash
   source ~/.config/cursor-readme/config.sh
   ./scripts/generate_readme.sh owner repo-name
   ```

4. **Push READMEs** (same as above)

### Manual Cursor IDE Integration Workflow

1. **Generate content in Cursor IDE** (manually)

2. **Save content to file** (e.g., `cursor-content.txt`)

3. **Integrate with README generation**:
   ```bash
   ./scripts/use_cursor_manual.sh owner repo-name cursor-content.txt
   ```

### Quick Test Workflow

```bash
# Test setup
./scripts/setup_summary.sh

# Test Cursor IDE
./scripts/check_cursor_ide.sh

# Test Ollama
./scripts/test_ollama.sh

# Test integration
./scripts/test_cursor_mcp.sh
```

### Troubleshooting Workflow

1. **Check status**:
   ```bash
   ./scripts/check_cursor_ide.sh
   ./scripts/setup_summary.sh
   ```

2. **Fix issues**:
   ```bash
   # Fix Node.js
   ./scripts/upgrade_nodejs.sh
   
   # Fix MCP
   ./scripts/fix_mcp_cursor.sh
   ./scripts/fix_mcp_config.sh
   
   # Fix npm path
   ./scripts/fix_npm_path.sh
   ```

3. **Re-run tests**:
   ```bash
   ./scripts/test_cursor_mcp.sh
   ```

---

## Script Dependencies

### Required Tools
- `bash` (version 4.0+)
- `curl` (for API requests)
- `jq` (for JSON parsing)
- `git` (for repository operations)

### Optional Tools (for AI features)
- `node` (version 18+, for MCP servers)
- `npm` / `npx` (for MCP servers)
- `ollama` (for local AI, optional)
- Cursor IDE (for cursor-agent mode, optional)

### Configuration Files
- `~/.config/cursor-readme/config.sh` (created by `configure_cursor_ai.sh`)
- `~/.config/mcp-readme/config.sh` (created by `setup_mcp.sh`)
- `~/.config/Cursor/User/mcp.json` (created by `setup_cursor_mcp.sh`)

---

## Quick Reference

### Most Frequently Used Scripts

| Script | Purpose | Required? |
|--------|---------|-----------|
| `generate_readme.sh` | Generate README files | ⭐ Yes |
| `search_repos.sh` | Search GitHub repos | ⭐ Yes |
| `fork_repos.sh` | Fork repos | ⭐ Yes |
| `push_readme.sh` | Push READMEs to GitHub | ⭐ Yes |
| `configure_cursor_ai.sh` | Setup AI config | 🔧 For AI |
| `complete_setup.sh` | Complete setup | 🔧 Recommended |
| `check_cursor_ide.sh` | Check Cursor status | 🔗 Useful |
| `test_ollama.sh` | Test Ollama | 🧪 Debug |

### Script File Sizes

Large scripts (>10KB):
- `generate_readme.sh` (~2000 lines) - Main README generator
- `search_repos.sh` (~700 lines) - Repository search
- `fork_repos.sh` (~530 lines) - Repository forking
- `push_readme.sh` (~330 lines) - README pushing
- `complete_setup.sh` (~407 lines) - Complete setup
- `configure_cursor_ai.sh` (~234 lines) - AI configuration

Medium scripts (2-10KB):
- `integrate_cursor_ai.sh` (~283 lines) - Cursor integration
- `check_cursor_ide.sh` (~283 lines) - Cursor checking
- `use_cursor_manual.sh` (~137 lines) - Manual Cursor integration
- `test_cursor_mcp.sh` (~168 lines) - MCP testing
- `setup_cursor_mcp.sh` (~166 lines) - Cursor MCP setup
- `setup_mcp.sh` (~218 lines) - MCP setup

Small scripts (<2KB):
- All test scripts
- All fix scripts
- Utility scripts

---

## Notes

- **Required vs Optional**: Required scripts are needed for core functionality. Optional scripts add features or help with troubleshooting.
- **AI Features**: AI-powered README generation requires setup scripts and optional dependencies (Node.js, Ollama, or API keys).
- **Error Handling**: All scripts include error handling and colored output for better user experience.
- **Configuration**: Most scripts support environment variables for configuration (e.g., `GITHUB_TOKEN`, `AI_ENABLED`).
- **Logging**: Core scripts generate logs for troubleshooting (e.g., `fork_log.txt`, `failed_forks.txt`).
