# README Generation Prompt for AI Agents

## Overview
This document provides comprehensive instructions for AI agents to analyze GitHub repositories and generate high-quality, consistent README.md files for the Universal Verification Methodology organization.

## Context
The Universal Verification Methodology organization aims to improve open-source verification IP (VIP) and verification methodology projects by:
- Forking repositories with poor or missing documentation
- Generating comprehensive README.md files that follow consistent standards
- Making projects more accessible to newcomers in the verification community

## Repository Analysis Phase

### Step 1: Repository Structure Analysis
Before generating the README, thoroughly analyze the repository:

1. **Examine the Codebase Structure**
   - Identify the programming language(s) used (SystemVerilog, Verilog, Python, etc.)
   - Map out the directory structure and organization
   - Identify key components, modules, or packages
   - Note any build systems (Makefile, CMake, setup.py, etc.)
   - Identify test directories and test frameworks

2. **Review Existing Documentation**
   - Check for existing README.md (even if minimal)
   - Look for LICENSE files
   - Check for documentation directories (docs/, Documentation/, etc.)
   - Review any inline code comments
   - Check for CHANGELOG, CONTRIBUTING, or similar files

3. **Analyze Code Metadata**
   - Extract project name and purpose from code comments
   - Identify version numbers or tags
   - Determine dependencies and requirements
   - Identify supported tools and versions (simulators, synthesis tools, etc.)
   - Check for configuration files (config files, YAML, JSON, etc.)

4. **Understand Project Purpose**
   - Determine if it's a Verification IP (VIP), testbench, utility, or methodology
   - Identify the protocol or standard it implements (AMBA, AXI, AHB, etc.)
   - Understand the target use case and audience
   - Identify key features and capabilities

### Step 2: Code Analysis
Deep dive into the code to understand functionality:

1. **Entry Points**
   - Identify main files, top-level modules, or entry scripts
   - Find example files or test cases
   - Locate configuration or setup files

2. **Dependencies**
   - List all external dependencies
   - Identify required tools and their versions
   - Note any optional dependencies

3. **Key Features**
   - Extract major features from code structure
   - Identify supported protocols, standards, or interfaces
   - Note any unique or distinguishing features

4. **Usage Patterns**
   - Analyze example code or test cases
   - Identify common usage patterns
   - Understand configuration options

## README Generation Guidelines

### Required Sections

#### 1. Header Section
```markdown
# Project Name

[Brief one-line description of what the project does]

[Optional: Badges for build status, license, version, etc.]
```

**Guidelines:**
- Use clear, descriptive project name
- Provide a concise tagline (one sentence)
- Add relevant badges if applicable (license, build status, etc.)

#### 2. Overview/Description
```markdown
## Overview

[2-3 paragraphs describing:]
- What the project is
- What problem it solves
- Who would use it
- Key benefits or features
```

**Guidelines:**
- Write for both beginners and experts
- Explain the "why" not just the "what"
- Use clear, jargon-free language (with technical terms explained)
- Highlight unique selling points

#### 3. Features
```markdown
## Features

- Feature 1: Description
- Feature 2: Description
- Feature 3: Description
```

**Guidelines:**
- List 5-10 key features
- Be specific and concrete
- Focus on user benefits
- Use bullet points for readability

#### 4. Requirements/Prerequisites
```markdown
## Requirements

### Tools
- Tool name and version
- Another tool and version

### Dependencies
- Dependency 1
- Dependency 2
```

**Guidelines:**
- List all required tools with minimum versions
- Include all dependencies
- Specify operating system requirements if relevant
- Mention any hardware requirements if applicable

#### 5. Installation
```markdown
## Installation

### Method 1: [Primary Method]
[Step-by-step instructions]

### Method 2: [Alternative Method]
[Step-by-step instructions]
```

**Guidelines:**
- Provide clear, step-by-step instructions
- Include multiple installation methods if applicable
- Show exact commands to run
- Include verification steps
- Mention common issues and solutions

#### 6. Quick Start
```markdown
## Quick Start

[Simple example showing basic usage]

```code
[Example code block]
```
```

**Guidelines:**
- Provide a minimal working example
- Show the most common use case
- Include expected output
- Keep it simple and focused

#### 7. Usage/Examples
```markdown
## Usage

### Basic Usage
[Description and example]

### Advanced Usage
[Description and example]
```

**Guidelines:**
- Provide multiple examples
- Progress from simple to complex
- Include code snippets with explanations
- Show different use cases
- Include expected outputs

#### 8. Project Structure
```markdown
## Project Structure

```
project/
├── directory1/
│   ├── file1
│   └── file2
├── directory2/
└── README.md
```

[Brief explanation of key directories and files]
```

**Guidelines:**
- Show the directory tree
- Explain the purpose of key directories
- Point out important files
- Keep it concise but informative

#### 9. Configuration
```markdown
## Configuration

[Explain configuration options, files, and parameters]
```

**Guidelines:**
- Document all configuration options
- Explain default values
- Provide example configurations
- Link to detailed documentation if available

#### 10. Testing
```markdown
## Testing

[How to run tests]

```bash
[Test commands]
```
```

**Guidelines:**
- Explain how to run tests
- Show example test commands
- Explain test structure if relevant
- Mention test coverage if available

#### 11. Contributing
```markdown
## Contributing

Contributions are welcome! Please follow these guidelines:
- [Guideline 1]
- [Guideline 2]

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.
```

**Guidelines:**
- Encourage contributions
- Provide basic guidelines
- Link to detailed contributing guide if exists
- Mention code style requirements

#### 12. License
```markdown
## License

This project is licensed under the [License Name] License - see the [LICENSE](LICENSE) file for details.
```

**Guidelines:**
- Always include license information
- Link to LICENSE file
- Be accurate about license type

#### 13. Acknowledgments/Credits
```markdown
## Acknowledgments

- [Credit 1]
- [Credit 2]
- Original repository: [Link if forked]
```

**Guidelines:**
- Credit original authors if forked
- Acknowledge contributors
- Mention inspiration or related projects

### Optional Sections (Add if Relevant)

- **Troubleshooting**: Common issues and solutions
- **FAQ**: Frequently asked questions
- **Roadmap**: Future plans and features
- **Changelog**: Link to changelog or recent changes
- **Performance**: Performance characteristics or benchmarks
- **Compatibility**: Supported versions, tools, or platforms
- **Related Projects**: Links to related or similar projects

## Writing Style Guidelines

### Tone and Voice
- **Professional but approachable**: Write for both experts and newcomers
- **Clear and concise**: Avoid unnecessary jargon
- **Action-oriented**: Use active voice
- **Helpful**: Anticipate user questions

### Technical Writing Best Practices
1. **Use consistent terminology**: Define acronyms on first use
2. **Provide context**: Explain why, not just what
3. **Use examples liberally**: Show, don't just tell
4. **Be specific**: Avoid vague statements
5. **Update regularly**: Note if information might be outdated

### Formatting Guidelines
1. **Use proper markdown**: Follow markdown best practices
2. **Consistent headings**: Use proper heading hierarchy (##, ###, ####)
3. **Code blocks**: Always specify language for syntax highlighting
4. **Lists**: Use consistent list formatting
5. **Links**: Use descriptive link text, not raw URLs
6. **Images**: Include alt text for accessibility

## Verification Methodology Specific Guidelines

### For Verification IP (VIP) Projects
Include:
- **Protocol/Standard**: Which protocol or standard is implemented
- **Compliance**: Protocol version and compliance level
- **Coverage**: Coverage model information
- **Test Suite**: Available test scenarios
- **Integration**: How to integrate with testbenches
- **Supported Simulators**: List of verified simulators

### For Testbench Projects
Include:
- **DUT Information**: What design is being tested
- **Test Scenarios**: What tests are included
- **Coverage Goals**: Coverage targets
- **Run Instructions**: How to execute tests
- **Results Interpretation**: How to understand results

### For Utility/Tool Projects
Include:
- **Purpose**: What problem it solves
- **Input/Output**: What it takes and produces
- **Use Cases**: Common scenarios
- **Integration**: How to use with other tools
- **Performance**: Speed, memory, etc.

## Quality Checklist

Before finalizing the README, verify:

- [ ] All required sections are present
- [ ] Installation instructions are complete and tested
- [ ] Code examples are correct and runnable
- [ ] All links work correctly
- [ ] License information is accurate
- [ ] Project structure is accurately represented
- [ ] Requirements are complete and accurate
- [ ] Examples demonstrate key features
- [ ] Writing is clear and free of errors
- [ ] Formatting is consistent throughout
- [ ] Technical terms are explained
- [ ] Screenshots or diagrams are included if helpful
- [ ] Version information is accurate
- [ ] Contact or support information is provided if relevant

## Example README Structure

```markdown
# Project Name

[Brief description]

[Badges]

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Overview
[Content]

## Features
[Content]

## Requirements
[Content]

## Installation
[Content]

## Quick Start
[Content]

## Usage
[Content]

## Project Structure
[Content]

## Configuration
[Content]

## Testing
[Content]

## Contributing
[Content]

## License
[Content]

## Acknowledgments
[Content]
```

## Final Notes

1. **Accuracy First**: Ensure all information is accurate. If uncertain, note it or omit it.
2. **User-Centric**: Write from the user's perspective. What do they need to know?
3. **Maintainability**: Structure the README so it's easy to update.
4. **Completeness**: Aim for comprehensive documentation, but don't duplicate code comments.
5. **Consistency**: Follow the organization's style guide and this template.
6. **Accessibility**: Use clear language, proper formatting, and consider all skill levels.

## AI Agent Instructions

When generating a README:

1. **Start with Analysis**: Thoroughly analyze the repository before writing
2. **Follow the Template**: Use the structure provided above
3. **Be Comprehensive**: Include all relevant information discovered
4. **Be Accurate**: Only include information you can verify from the codebase
5. **Be Clear**: Write for users who may be new to the project
6. **Be Consistent**: Follow the formatting and style guidelines
7. **Review**: Check against the quality checklist before finalizing

Remember: A good README makes a project accessible. Your goal is to help newcomers understand and use the project effectively.
