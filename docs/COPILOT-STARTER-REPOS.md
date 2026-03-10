# GitHub Copilot Coding Agent — Starter Repos Setup Guide

This document answers three questions that came up during planning:

1. **Can the Copilot coding agent create new repositories?** No — and this explains why.
2. **How do you grant the agent write access to existing private repos?** Step-by-step below.
3. **How do you set up the four starter repos and let the agent populate them?** Full workflow at the end.

---

## Can the Agent Create Repositories?

**No.** The GitHub Copilot coding agent (and any GitHub App or OAuth app) operates within the
permissions it has been granted. Repository *creation* requires a separate `administration:write`
scope that Copilot's built-in integration does not request. The agent can only:

- Read and write **files** inside repos it already has access to
- Open pull requests inside those repos
- Read issues, CI results, and discussions

This is intentional: letting an automated agent create repos under your account without an explicit
confirmation step would be a significant privilege escalation.

**Practical consequence:** You must create each repo on GitHub first (empty is fine), then invoke
the agent to push the starter skeleton as a pull request.

---

## Granting the Agent Write Access to Private Repos

### 1 — Verify the GitHub Copilot App is installed

The coding-agent feature runs through the **GitHub Copilot** GitHub App. Confirm it is installed:

1. Go to **GitHub → Settings → Applications → Installed GitHub Apps**
   `https://github.com/settings/installations`
2. Find **GitHub Copilot** in the list (it was installed when you subscribed to Copilot Pro).
3. Click **Configure**.

### 2 — Add each private repo to the app's allowed list

On the Copilot app configuration page:

1. Under **Repository access**, choose **Only select repositories**.
2. Click **Select repositories** and add each private repo you want the agent to access:
   - `errorproofdev/starter-nextjs`
   - `errorproofdev/starter-node`
   - `errorproofdev/start-python` *(note: `start-`, not `starter-`)*
   - `errorproofdev/starter-swift`
3. Click **Save**.

> **Note:** Choosing "All repositories" is faster but grants access to every current and future
> private repo. Prefer the explicit list until you are comfortable with the agent's behavior.

### 3 — Enable Copilot coding agent in each repo

1. Navigate to the repo → **Settings → Code and automation → GitHub Copilot**.
2. Toggle **"Allow GitHub Copilot to create and review pull requests"** to **On**.
3. Repeat for each of the four repos.

### 4 — OAuth App scope (optional / VS Code only)

If you also use Copilot from **VS Code** and want the VS Code extension to read private repos
(e.g., for workspace context), ensure the **GitHub Copilot OAuth App** has `repo` scope:

1. Go to **GitHub → Settings → Applications → Authorized OAuth Apps**.
2. Find **GitHub Copilot** (OAuth app, different from the GitHub App above).
3. If the `repo` scope is missing, revoke and re-authorize from VS Code
   (**Cmd+Shift+P → GitHub: Sign In**).

---

## Creating the Four Starter Repos

All repos should be **private**, default branch **`main`**, initialized with no files (empty).

### Via GitHub UI (fastest)

Repeat for each repo name:

1. Go to `https://github.com/new`
2. **Owner:** `errorproofdev`
3. **Repository name:** see table below
4. **Visibility:** Private
5. **Initialize with:** *(leave all checkboxes unchecked — empty repo)*
6. Click **Create repository**

| Repo name | Stack |
|---|---|
| `starter-nextjs` | Next.js 15 · TypeScript · Tailwind · Postgres · pnpm |
| `starter-node` | Node 22 LTS · TypeScript · Express/Hono · Postgres · pnpm |
| `start-python` | Python 3.12 · Poetry · FastAPI · Postgres |
| `starter-swift` | iOS 17+ · SwiftUI · Swift Package Manager |

> **`start-python`** uses `start-` (not `starter-`) — this matches the name specified during
> planning. Rename the repo to `starter-python` on GitHub if you prefer consistency, and update
> all references in this document accordingly.

### Via GitHub CLI (one-liner per repo)

```bash
gh repo create errorproofdev/starter-nextjs --private --confirm
gh repo create errorproofdev/starter-node   --private --confirm
gh repo create errorproofdev/start-python   --private --confirm
gh repo create errorproofdev/starter-swift  --private --confirm
```

---

## What Each Starter Repo Should Contain

The sections below describe the intended skeleton for each repo. When you ask the agent to
populate a repo, paste the relevant section as context inside your issue or chat message.

### `starter-nextjs`

```
.github/
  copilot-instructions.md     # Stack conventions: pnpm, Tailwind, Prisma, Podman
  agents/
    nextjs-architect.agent.md
    db-prisma.agent.md
    podman-compose.agent.md
    security-review.agent.md
.vscode/
  extensions.json             # ESLint, Prettier, Tailwind IntelliSense, Prisma
  settings.json               # format-on-save, pnpm as package manager
SKILLS.md                     # How to use each agent; definition of done; prompts
mcp.json                      # Minimal MCP config (no cloud credentials required)
.gitignore                    # Node, Next.js, .env, .DS_Store, Podman/Docker volumes
.env.example                  # DATABASE_URL, NEXTAUTH_SECRET, NEXTAUTH_URL
compose.yaml                  # Postgres 16 + optional app container (Podman Compose)
Containerfile                 # Multi-stage build for the Next.js app
Makefile                      # up / down / db-migrate / test / lint targets
README.md                     # Quick start, env setup, Podman instructions
package.json                  # pnpm workspaces; Next.js 15, TypeScript, Tailwind, Prisma
pnpm-lock.yaml
tsconfig.json
eslint.config.mjs             # ESLint flat config with TypeScript + Next.js rules
.prettierrc
prisma/
  schema.prisma               # Postgres datasource; User model as baseline
  migrations/                 # (empty; first migration generated with `pnpm db:migrate`)
src/
  app/
    layout.tsx
    page.tsx
    globals.css
  lib/
    db.ts                     # Prisma client singleton
```

**Package manager:** `pnpm` (deterministic, workspace-friendly, fast on CI).

**Database:** Prisma + Postgres running in a Podman container locally; Supabase for production
(swap `DATABASE_URL` in `.env`).

---

### `starter-node`

```
.github/
  copilot-instructions.md     # Stack conventions: pnpm, Hono/Express, Prisma, Podman
  agents/
    node-api.agent.md
    db-prisma.agent.md
    podman-compose.agent.md
    security-review.agent.md
.vscode/
  extensions.json             # ESLint, Prettier, REST Client
  settings.json
SKILLS.md
mcp.json
.gitignore                    # Node, dist/, .env, .DS_Store
.env.example                  # DATABASE_URL, PORT, NODE_ENV
compose.yaml                  # Postgres 16 (Podman Compose)
Containerfile
Makefile
README.md
package.json                  # pnpm; TypeScript, Hono (or Express), Prisma, ts-node-dev
pnpm-lock.yaml
tsconfig.json
eslint.config.mjs
.prettierrc
prisma/
  schema.prisma
  migrations/
src/
  index.ts                    # App entry point; starts HTTP server
  routes/
    health.ts                 # GET /health — liveness check
  lib/
    db.ts                     # Prisma client singleton
```

**Package manager:** `pnpm`.

**Framework:** Hono is recommended for new APIs (tiny, fast, type-safe); include a comment in
`copilot-instructions.md` noting "prefer Hono; swap for Express if existing code requires it".

---

### `start-python`

```
.github/
  copilot-instructions.md     # Stack conventions: Poetry, ruff, pytest, Podman, FastAPI
  agents/
    python-fastapi.agent.md
    db-sqlalchemy.agent.md
    podman-compose.agent.md
    security-review.agent.md
.vscode/
  extensions.json             # Python, Pylance, Ruff, REST Client
  settings.json               # python.defaultInterpreterPath points to Poetry venv
SKILLS.md
mcp.json
.gitignore                    # Python, __pycache__, .env, .DS_Store, .venv
.env.example                  # DATABASE_URL, SECRET_KEY, ENVIRONMENT
compose.yaml                  # Postgres 16 (Podman Compose)
Containerfile                 # Multi-stage Python image
Makefile                      # install / up / down / test / lint / migrate targets
README.md
pyproject.toml                # Poetry config: Python 3.12, FastAPI, SQLAlchemy, Alembic
poetry.lock
ruff.toml                     # Linting + formatting (replaces Black + Flake8 + isort)
pytest.ini
app/
  main.py                     # FastAPI app factory
  config.py                   # Settings via pydantic-settings
  database.py                 # SQLAlchemy async session
  models/
    user.py                   # Baseline User model
  routes/
    health.py                 # GET /health
  schemas/
    user.py                   # Pydantic request/response schemas
alembic/
  env.py
  versions/                   # (empty; first migration generated with `make migrate`)
tests/
  conftest.py
  test_health.py
```

**Package manager:** `Poetry` (reproducible lockfile; `pyproject.toml`-based).

**Linter/formatter:** `ruff` (single tool replacing Black + Flake8 + isort; much faster).

---

### `starter-swift`

```
.github/
  copilot-instructions.md     # Stack: SwiftUI, MVVM, SPM, SwiftLint, async/await
  agents/
    swiftui-architect.agent.md
    ios-testing.agent.md
    accessibility.agent.md
SKILLS.md
mcp.json
.gitignore                    # Xcode, DerivedData, xcuserstate, .DS_Store, SPM .build
README.md                     # "Open in Xcode" steps, SwiftLint setup, CI notes
.swiftlint.yml                # Sensible defaults; opt out of overly strict rules

StarterApp/                   # Xcode project root
  StarterApp.xcodeproj/
  StarterApp/
    StarterAppApp.swift       # @main entry, TabView root
    ContentView.swift         # Root content (hosts MainTabView)
    Views/
      MainTabView.swift       # TabView with 3 tabs: Home / Explore / Settings
      Home/
        HomeView.swift
        HomeViewModel.swift
      Explore/
        ExploreView.swift
        ExploreViewModel.swift
      Settings/
        SettingsView.swift
    Models/
      AppInfo.swift           # Version, build number, environment
    Services/
      NetworkService.swift    # URLSession async/await wrapper
    Resources/
      Assets.xcassets
      LaunchScreen.storyboard (or Info.plist SwiftUI variant)
  StarterAppTests/
    StarterAppTests.swift
  StarterAppUITests/
    StarterAppUITests.swift
```

**Architecture:** MVVM with `@Observable` (iOS 17+); one `ViewModel` per screen.

**Navigation:** `TabView` (bottom tab bar) with `NavigationStack` inside each tab.

**Dependency management:** Swift Package Manager only (no CocoaPods/Carthage).

**Note:** Xcode project files (`.xcodeproj`) cannot be generated by the agent without running
Xcode locally. See *"Populating starter-swift"* below for the recommended workflow.

---

## Running the Agent to Populate Each Repo

### General pattern

1. Open the target repo on GitHub.
2. Create a new **Issue** titled *"Initialize starter skeleton"* (or similar).
3. In the issue body, paste the relevant "What it should contain" section above plus any
   customizations you want.
4. Assign the issue to **@copilot** (or click **"Ask Copilot"** / **"Start working"**).
5. The agent will open a pull request with the initial file tree.
6. Review the PR, request any changes, then merge.

### Prompt template (paste into the issue body)

> Replace `<STACK SECTION>` with the relevant block from the section above.

```
Initialize this repo with the starter skeleton described below.

**Goal:** A minimal, production-hygiene starting point for new projects using this stack.
Keep it simple — no business logic, no sample data. Every file should be real and runnable.

**Stack and file tree:**
<STACK SECTION>

**Constraints:**
- pnpm (or Poetry / SPM) as the package manager — no npm/yarn/pip/CocoaPods
- Podman Compose (not Docker Compose) for local containers; use `compose.yaml` filename
- `.env.example` must include every variable referenced in the codebase
- `.gitignore` must exclude: secrets, build artifacts, editor state, Podman volumes
- All TypeScript must be strict mode (`"strict": true` in tsconfig)
- No placeholder/TODO comments in generated code — either implement or omit
- README must include: prerequisites, local setup steps, available `make` targets

Open a pull request when ready.
```

### Populating `starter-swift` (special case)

Because Xcode generates binary project files, the agent cannot scaffold a working `.xcodeproj`
from scratch. Use this two-step approach:

**Step 1 — Create the Xcode project locally:**

1. Open Xcode → **File → New → Project → iOS → App**
2. Product name: `StarterApp`, Interface: `SwiftUI`, Language: `Swift`
3. Include Tests: ✓
4. Save to a local directory, then:

```bash
cd path/to/StarterApp
git init
git remote add origin git@github.com:errorproofdev/starter-swift.git
git add .
git commit -m "chore: initial Xcode project scaffold"
git push -u origin main
```

**Step 2 — Let the agent add Copilot config and supporting files:**

Create an issue in `errorproofdev/starter-swift` with this prompt:

```
The Xcode project scaffold is already committed. Add the following files
on top of the existing project (do not modify .xcodeproj files):

- .github/copilot-instructions.md  (SwiftUI / MVVM / SPM conventions)
- .github/agents/swiftui-architect.agent.md
- .github/agents/ios-testing.agent.md
- .github/agents/accessibility.agent.md
- SKILLS.md
- mcp.json
- .swiftlint.yml
- README.md  (prerequisites, how to open in Xcode, SwiftLint setup, CI notes)

Also add the SwiftUI views listed below as new source files (place them
under StarterApp/Views/ following the MVVM layout described):

[paste the Views section from the "starter-swift" skeleton above]

Open a pull request when ready.
```

---

## Permissions Quick-Reference

| Action | Agent can do? | How to enable |
|---|---|---|
| Read files in a public repo | ✅ Yes | No setup required |
| Read files in a private repo | ✅ Yes (with access) | Add repo to Copilot App installation |
| Push commits / open PRs in a private repo | ✅ Yes (with access) | Add repo + enable coding agent in repo settings |
| Create a new repository | ❌ No | Create manually, then grant access |
| Delete a repository | ❌ No | Not possible via Copilot agent |
| Manage GitHub App / OAuth App settings | ❌ No | Configure in GitHub Settings |
| Access repo secrets / Actions secrets | ❌ No | Secrets are not exposed to the agent |

---

## Troubleshooting

### "Repository not found" when assigning issue to @copilot

- Confirm the repo is listed under **Settings → Applications → GitHub Copilot → Configure →
  Repository access**.
- Confirm **GitHub Copilot coding agent** is enabled in the repo's own settings
  (**repo → Settings → Code and automation → GitHub Copilot**).

### Agent opens a PR but it's missing files

The agent respects the prompt literally. If a file is missing, either:

- It was not listed in the prompt — add it and re-request.
- The agent hit a context limit — break the request into smaller issues (one per "layer", e.g.,
  "add Copilot config files" then "add application source files").

### Copilot Pro cost and coding agent usage

The coding agent (PR-making) consumes **"premium requests"** from your Copilot Pro quota.
Monitor usage at **github.com/settings/copilot**. As of early 2026, each agent turn costs
roughly 1 premium request; complex multi-file PRs may use several turns.

MCP servers add tool calls per agent turn — keep MCP servers local or read-only until you are
comfortable with usage.

---

*Last updated: 2026-03-10*
