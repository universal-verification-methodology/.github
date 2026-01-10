# README Generation Scripts

This directory contains scripts for generating and pushing README.md files to GitHub repositories using the GitHub API, **without cloning** the repositories.

## Scripts Overview

### 1. `generate_readme.sh` - Generate README.md Locally
Generates README.md files by analyzing repositories via GitHub API and saves them locally.

**Usage:**
```bash
# Single repository
./scripts/generate_readme.sh owner repo_name [output_file] [branch]

# All repositories in organization
./scripts/generate_readme.sh owner --org [output_dir] [branch]
```

**Example:**
```bash
./scripts/generate_readme.sh universal-verification-methodology .github
```

### 2. `push_readme.sh` - Push README.md to Repository
Pushes existing README.md files to GitHub repositories via API (no git clone needed).

**Usage:**
```bash
# Single repository
./scripts/push_readme.sh owner repo_name [readme_file] [branch] [commit_message]

# All repositories in organization
./scripts/push_readme.sh owner --org [readme_dir] [branch] [commit_message]
```

**Example:**
```bash
./scripts/push_readme.sh universal-verification-methodology .github README.md
```

### 3. `generate_and_push_readme.sh` - Combined (Legacy)
Original combined script that generates and pushes in one step. Still available for convenience.

**Usage:**
```bash
./scripts/generate_and_push_readme.sh owner repo_name [branch]
./scripts/generate_and_push_readme.sh owner --org [branch]
```

## Quick Start

### Recommended Workflow: Generate → Review → Push

```bash
# Step 1: Generate READMEs for all repos
./scripts/generate_readme.sh \
    universal-verification-methodology \
    --org \
    ./readmes

# Step 2: Review the generated READMEs
ls -la ./readmes/*/README.md

# Step 3: Push all READMEs
./scripts/push_readme.sh \
    universal-verification-methodology \
    --org \
    ./readmes
```

## Features

- ✅ **No git clone required** - Everything via GitHub API
- ✅ **Default token included** - Ready to use out of the box
- ✅ **Modular design** - Generate and push separately
- ✅ **Organization support** - Process all repos at once
- ✅ **Follows PROMPT.md** - Comprehensive README structure

## Documentation

- **`SPLIT_SCRIPTS_USAGE.md`** - Detailed usage guide for split scripts
- **`SHELL_SCRIPT_USAGE.md`** - Usage guide for combined script

## Dependencies

- `bash` (version 4.0+)
- `curl` - For HTTP requests
- `jq` - For JSON parsing

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

## Default Token

All scripts use the default token: `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`

You can override it with:
```bash
export GITHUB_TOKEN=your_custom_token
```

## Which Script to Use?

| Use Case | Script |
|----------|--------|
| Generate and review before pushing | `generate_readme.sh` + `push_readme.sh` |
| Quick generate and push | `generate_and_push_readme.sh` |
| Push existing README | `push_readme.sh` |
| Generate only (no push) | `generate_readme.sh` |

## Examples

### Generate README for One Repo
```bash
./scripts/generate_readme.sh \
    universal-verification-methodology \
    .github \
    README.md
```

### Push README for One Repo
```bash
./scripts/push_readme.sh \
    universal-verification-methodology \
    .github \
    README.md \
    main \
    "docs: Update README"
```

### Generate READMEs for All Repos
```bash
./scripts/generate_readme.sh \
    universal-verification-methodology \
    --org \
    ./generated_readmes
```

### Push READMEs for All Repos
```bash
./scripts/push_readme.sh \
    universal-verification-methodology \
    --org \
    ./generated_readmes
```

## Error Handling

- Scripts continue processing remaining repos if one fails (in --org mode)
- Clear error messages for debugging
- Rate limit detection and warnings
- File existence checks before operations

## See Also

- `../PROMPT.md` - README generation guidelines
- `../SOLUTION_SUMMARY.md` - Overall solution overview
