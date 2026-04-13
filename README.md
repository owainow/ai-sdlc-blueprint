# ai-sdlc-blueprint

A stampable project blueprint for running an **AI-led Software Development Lifecycle** — CLI-first, no IDE required.

Built on [Spec Kit](https://github.com/github/spec-kit), [speckit-to-issue](https://github.com/owainow/speckit-to-issue), the [GitHub Coding Agent](https://docs.github.com/en/copilot/using-github-copilot/using-the-github-copilot-coding-agent), and Azure Container Apps.

Based on the approach in [An AI-led SDLC: Building an End-to-End Agentic Software Development Lifecycle with Azure and GitHub](https://techcommunity.microsoft.com/blog/appsonazureblog/an-ai-led-sdlc-building-an-end-to-end-agentic-software-development-lifecycle-wit/4491896).

## The Flow

```
You (CLI)                          GitHub                               Azure
─────────                          ──────                               ─────
specify → plan → tasks     →  speckit-to-issue  →  Issues
                                                      │
                                                Coding Agent  →  Branch + PR
                                                      │
                                              Code Quality Review
                                                      │
                                                Merge to main  →  GitHub Actions  →  Container Apps
                                                                                        │
                                                                                   SRE Agent  →  Issues
                                                                                                  ↑
                                                                                        (feedback loop)
```

Everything left of the arrow is you in a terminal. Everything right happens autonomously.

## Quick Start

### Prerequisites

```bash
# Required
gh auth login                         # GitHub CLI — authenticated
pip install speckit-to-issue          # or: pip install -e path/to/speckit-to-issue

# Spec Kit
uvx --from git+https://github.com/github/spec-kit.git specify --help

# Azure (for deployment)
az login
azd auth login
```

### 1. Stamp a project

```powershell
.\stamp.ps1 -ProjectName "my-app" -Description "My application" -GitHubOrg "myorg"
cd my-app
```

This copies the blueprint, replaces tokens, inits git, and runs `specify init`.

### 2. Create the GitHub repo and wire up Azure

```powershell
gh repo create myorg/my-app --public --push --source .
.\setup-azure.ps1 -ProjectName "my-app" -GitHubRepo "myorg/my-app"
```

This creates resource groups (dev/staging/prod), an Azure Container Registry, an Entra ID app with OIDC federation for GitHub Actions, role assignments, and sets all GitHub secrets/variables. One command — CI/CD works immediately.

### 3. Create a spec

Use Copilot CLI or any coding agent to generate the spec:

```bash
# With Copilot CLI
gh copilot "/specify As a user I want to view real-time weather data for my city"

# Or interactively with any agent that supports Spec Kit prompt files
```

This generates `specs/001-feature/requirements.md` with a full breakdown.

### 4. Plan & generate tasks

```bash
gh copilot "/plan"
gh copilot "/tasks"
```

You now have `plan.md` and `tasks.md` — a structured, testable breakdown respecting the constitution.

### 5. Push tasks to GitHub as issues

```bash
speckit-to-issue create specs/001-feature/tasks.md --assign-copilot
```

Each task becomes a GitHub issue. `--assign-copilot` assigns the coding agent automatically.

### 6. Let the coding agent build

The GitHub coding agent picks up assigned issues, creates a branch, implements the task, runs tests, and opens a PR. Monitor progress in the repo's **Actions** and **Pull requests** tabs.

### 7. Review & merge

PRs get AI code quality scanning + your review. Leave `@copilot` comments to request changes. Merge when ready — CI/CD deploys to Azure automatically.

## What's in the Blueprint

```
ai-sdlc-blueprint/
├── .specify/
│   └── constitution.md          # Project standards, tech stack, architecture rules
├── .github/
│   ├── copilot-instructions.md  # Instructions for Copilot CLI + GitHub coding agent
│   ├── ISSUE_TEMPLATE/
│   │   └── spec-task.md         # Issue template for spec-generated tasks
│   └── workflows/
│       ├── deploy.yml           # CI/CD: build → dev → staging → prod
│       └── pr-sandbox.yml       # Deploy PR revisions for live review
├── infra/
│   ├── main.bicep               # Azure Container Apps + App Insights + Log Analytics
│   └── main.bicepparam          # Environment parameters
├── specs/                       # Where Spec Kit generates specs, plans, and tasks
├── azure.yaml                   # Azure Developer CLI (azd) configuration
├── stamp.ps1                    # Project stamping script
├── setup-azure.ps1              # One-command Azure + GitHub wiring
└── README.md
```

No `.vscode/` directory. No IDE lock-in. Works from any terminal.

## Customising the Constitution

After stamping, edit `.specify/constitution.md` to define:

- **Tech stack** — language, framework, database
- **Architecture principles** — cloud-native, API-first, etc.
- **Testing requirements** — coverage thresholds, test types
- **Security standards** — auth, secrets management
- **Azure infrastructure** — resource naming, environments

The constitution is read by both Copilot CLI and the GitHub coding agent to ensure all code follows your standards.

## Azure Setup

All Azure provisioning and GitHub configuration is handled by `setup-azure.ps1`.

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) — authenticated (`az login`)
- [GitHub CLI (gh)](https://cli.github.com/) — authenticated (`gh auth login`)
- Azure permissions: Contributor + User Access Administrator (or Owner) on the subscription

### What it creates

```powershell
.\setup-azure.ps1 -ProjectName "my-app" -GitHubRepo "myorg/my-app"
```

| Resource | Details |
|---|---|
| Resource Groups | `rg-my-app-shared`, `rg-my-app-dev`, `rg-my-app-staging`, `rg-my-app-prod` |
| Container Registry | `myappacr` (Basic SKU, in `rg-my-app-shared`) |
| Entra ID App | `my-app-github-oidc` with OIDC federation for main, PRs, and each environment |
| Role Assignments | Contributor on RGs, AcrPush + AcrPull on ACR |
| GitHub Secrets | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| GitHub Variables | `ACR_NAME`, `PROJECT_NAME` |
| GitHub Environments | `dev`, `staging`, `prod` |

After running this, push to main or open a PR and the CI/CD workflows will work immediately.

### Optional flags

| Flag | Effect |
|---|---|
| `-Location "eastus2"` | Change Azure region (default: `uksouth`) |
| `-SubscriptionId "xxx"` | Target a specific subscription |
| `-SkipInfraProvision` | Skip resource group + ACR creation (if they already exist) |

## Dependencies

This blueprint orchestrates two external tools. Both are actively evolving.

| Tool | Repo | Install |
|---|---|---|
| [Spec Kit](https://github.com/github/spec-kit) | GitHub (open source) | `uvx --from git+https://github.com/github/spec-kit.git specify` |
| [speckit-to-issue](https://github.com/owainow/speckit-to-issue) | owainow (open source) | `pip install -e path/to/speckit-to-issue` |

The blueprint is loosely coupled to both — it just needs them on your `PATH`. As these tools evolve (e.g. speckit-to-issue gaining an MCP server), the blueprint benefits without changes.

## Roadmap

- [x] **Blueprint template repo** — stampable skeleton with constitution, workflows, IaC
- [x] **CLI-first flow** — no IDE dependency, works from any terminal
- [ ] **speckit-to-issue MCP server** — being built separately, will integrate with Copilot CLI
- [ ] **SRE Agent integration** — close the feedback loop from operations back to specs
- [ ] **Multi-template support** — different constitutions for different app archetypes

## License

MIT
