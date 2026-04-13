# ai-sdlc-blueprint

A stampable project blueprint for running an **AI-led Software Development Lifecycle** using spec-driven development, autonomous coding agents, and Azure-native infrastructure.

Based on the approach described in [An AI-led SDLC: Building an End-to-End Agentic Software Development Lifecycle with Azure and GitHub](https://techcommunity.microsoft.com/blog/appsonazureblog/an-ai-led-sdlc-building-an-end-to-end-agentic-software-development-lifecycle-wit/4491896).

## The Flow

```
Idea → Spec Kit → Tasks → GitHub Issues → Coding Agent → PR + Quality Review → CI/CD → Azure → SRE Agent
         ↑                                                                                        │
         └────────────────────── Feedback loop (issues from SRE agent) ───────────────────────────┘
```

### 5 Steps

| Step | Tool | What Happens |
|---|---|---|
| 1. Specify | [Spec Kit](https://github.com/github/spec-kit) | Idea → requirements → plan → tasks |
| 2. Implement | [GitHub Coding Agent](https://docs.github.com/en/copilot/using-github-copilot/using-the-github-copilot-coding-agent) | Tasks (as issues) → code → PR |
| 3. Review | GitHub Code Quality + Human | AI + human review of PRs |
| 4. Deploy | GitHub Actions + Azure | Build → Container Apps (dev → staging → prod) |
| 5. Operate | Azure SRE Agent | Proactive monitoring → auto-opened issues |

## Quick Start

### Stamp a new project

```powershell
.\stamp.ps1 -ProjectName "my-app" -Description "My application" -GitHubOrg "myorg"
```

This will:
1. Copy the blueprint to a new `my-app/` directory
2. Replace all placeholder tokens with your project values
3. Initialise git with an initial commit
4. Run `specify init` to set up Spec Kit

### Start building

```
cd my-app
code .
```

Then use the **@SDLC** agent in VS Code:

> @SDLC Build me a real-time weather dashboard that shows current conditions and 5-day forecasts for any city.

The agent will walk through: Specify → Plan → Tasks → Create Issues.

## What's in the Blueprint

```
ai-sdlc-blueprint/
├── .specify/
│   └── constitution.md          # Project standards, tech stack, architecture rules
├── .github/
│   ├── copilot-instructions.md  # Instructions for GitHub Copilot coding agent
│   ├── ISSUE_TEMPLATE/
│   │   └── spec-task.md         # Issue template for spec-generated tasks
│   └── workflows/
│       ├── deploy.yml           # CI/CD: build → dev → staging → prod
│       └── pr-sandbox.yml       # Deploy PR revisions for live review
├── .vscode/
│   ├── agents/
│   │   └── sdlc.agent.md       # @SDLC orchestrator agent for VS Code
│   └── mcp.json                 # MCP server config (Layer 2 placeholder)
├── infra/
│   ├── main.bicep               # Azure Container Apps + App Insights + Log Analytics
│   └── main.bicepparam          # Environment parameters
├── azure.yaml                   # Azure Developer CLI (azd) configuration
├── stamp.ps1                    # Project stamping script
└── README.md                    # This file
```

## Customising the Constitution

After stamping, edit `.specify/constitution.md` to define:

- **Tech stack** — language, framework, database, etc.
- **Architecture principles** — cloud-native, API-first, etc.
- **Testing requirements** — coverage thresholds, test types
- **Security standards** — auth, secrets management
- **Azure infrastructure** — resource naming, environments

The constitution is read by both the @SDLC agent and the coding agent to ensure all code adheres to your standards.

## Azure Setup

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [GitHub CLI (gh)](https://cli.github.com/)

### Configure environments

```bash
# Login
az login
azd auth login

# Provision dev environment
azd provision --environment dev

# Set up GitHub OIDC for Actions
az ad app create --display-name "my-app-github"
# Then configure federated credentials for your repo
```

### Required GitHub Secrets/Variables

| Name | Type | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | Service principal / app registration client ID |
| `AZURE_TENANT_ID` | Secret | Entra ID tenant |
| `AZURE_SUBSCRIPTION_ID` | Secret | Target subscription |
| `ACR_NAME` | Variable | Azure Container Registry name (without .azurecr.io) |
| `PROJECT_NAME` | Variable | Project name (matches stamp) |

## Dependencies

This blueprint orchestrates two external tools. Both are actively evolving.

| Tool | Repo | Status |
|---|---|---|
| [Spec Kit](https://github.com/github/spec-kit) | GitHub (open source) | Stable — install via `uvx` |
| [speckit-to-issue](https://github.com/owainow/speckit-to-issue) | owainow (open source) | Active — CLI works, MCP server in progress |

The blueprint is loosely coupled to both. When speckit-to-issue's MCP server is ready, enable it in `.vscode/mcp.json` and the @SDLC agent will automatically prefer MCP tools over CLI.

## Roadmap

- [x] **Blueprint template repo** — stampable skeleton with constitution, workflows, IaC, agent
- [ ] **speckit-to-issue MCP server** — being built separately in the speckit-to-issue repo
- [ ] **Enhanced @SDLC agent** — upgraded when MCP tools are available
- [ ] **SRE Agent integration** — close the feedback loop from operations back to specs

## License

MIT
