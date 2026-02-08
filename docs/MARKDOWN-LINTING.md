# Markdown Linting Setup

This project uses markdown linting to maintain consistent formatting and quality across all documentation.

## Installation

### 1. Install markdownlint CLI

```bash
npm install -g markdownlint-cli
# or
brew install markdownlint-cli
```

### 2. Install pre-commit Framework

```bash
pip install pre-commit
# or
brew install pre-commit
```

### 3. Set Up Pre-Commit Hooks

```bash
cd /Users/josephvore/CODE/vps-setup
pre-commit install
```

### 4. Install VS Code Extension (Optional)

Install the [markdownlint extension](vscode:extension/DavidAnson.vscode-markdownlint) for real-time linting in the editor.

## Usage

### Automatic (On Save)

- VS Code automatically formats markdown files on save
- Pre-commit hooks run automatically on `git commit`

### Manual

```bash
# Lint all markdown files
markdownlint '**/*.md'

# Fix markdown files automatically
markdownlint --fix '**/*.md'

# Run pre-commit checks manually
pre-commit run --all-files
```

## Configuration

### Markdown Linting Rules

Rules are defined in `.markdownlint.json`:

- Line length: 120 characters (soft limit)
- Indentation: 2 spaces
- Consistent style for lists and emphasis
- HTML tags allowed in markdown
- Multiple H1 headings allowed per file

### Pre-Commit Hooks

Configured in `.pre-commit-config.yaml`:

1. **markdownlint** - Lints markdown with --fix to auto-correct
2. **Merge conflict check** - Ensures no unresolved conflicts
3. **Trailing whitespace** - Removes trailing spaces
4. **End of file fixer** - Ensures files end with newline

## Workflow

### Before Committing

```bash
# Check what pre-commit will do
pre-commit run --all-files

# Or just commit - hooks run automatically
git commit -m "docs: update documentation"
```

### On File Save

VS Code automatically:

1. Formats markdown according to `.markdownlint.json`
2. Fixes issues with markdownlint auto-fix
3. Removes trailing whitespace
4. Ensures proper EOF

## Troubleshooting

### Pre-commit not running?

```bash
pre-commit install
pre-commit run --all-files
```

### Linting fails locally but passes in CI?

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Run all checks
pre-commit run --all-files
```

### Want to disable a specific rule?

Edit `.markdownlint.json` and set to `false`:

```json
{
  "MD033": false,
  "MD041": false
}
```

## Rules Reference

Common rules:

- **MD001** - Heading levels should increase by one
- **MD003** - Heading style (consistent)
- **MD013** - Line length (120 chars)
- **MD024** - Duplicate headings (siblings only)
- **MD033** - Inline HTML (allowed here)
- **MD040** - Code blocks must have language specified
- **MD041** - First line in file must be H1

See [markdownlint rules](https://github.com/DavidAnson/markdownlint/blob/main/README.md#rules--aliases) for complete list.
