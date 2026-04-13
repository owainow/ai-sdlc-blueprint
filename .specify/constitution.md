# Project Constitution

> This constitution defines the standards, constraints, and preferences that govern all specifications, plans, and implementations in this project. Update this file when you stamp a new project from the blueprint.

## Project Identity

- **Name:** {{PROJECT_NAME}}
- **Description:** {{PROJECT_DESCRIPTION}}
- **Repository:** {{GITHUB_ORG}}/{{PROJECT_NAME}}

## Tech Stack

- **Runtime:** Node.js 22 / Python 3.12 (depending on project)
- **Frontend:** React 19 + TypeScript + Vite
- **Backend:** Azure Container Apps
- **Database:** Azure Cosmos DB (NoSQL) or Azure Database for PostgreSQL Flexible Server
- **Auth:** Microsoft Entra ID (MSAL)
- **IaC:** Bicep + Azure Developer CLI (azd)
- **CI/CD:** GitHub Actions
- **Monitoring:** Azure Monitor + Application Insights
- **Containerisation:** Docker multi-stage builds targeting linux/amd64

## Architecture Principles

1. **Cloud-native, Azure-first.** All infrastructure runs on Azure. No multi-cloud abstractions.
2. **Twelve-factor app.** Config via environment variables, stateless processes, disposable containers.
3. **API-first.** Backend exposes a versioned REST API. Frontend is a separate SPA.
4. **Zero-trust security.** Managed identities for service-to-service auth. No secrets in code.
5. **Observable by default.** Structured logging, distributed tracing, health endpoints from day one.

## Development Standards

### Code Quality
- TypeScript strict mode enabled. No `any` types.
- Python code uses type hints and passes `mypy --strict`.
- All public APIs have OpenAPI specs.
- Linting: ESLint (TS), Ruff (Python). No warnings allowed.

### Testing
- **TDD approach.** Write tests before or alongside implementation.
- **Unit test coverage:** minimum 80%.
- **Integration tests** for all API endpoints.
- **E2E tests** using Playwright for UI-facing features.
- Tests must pass in CI before merge.

### Git & Branching
- Trunk-based development with short-lived feature branches.
- Branch naming: `feat/spec-NNN-description`, `fix/spec-NNN-description`.
- Squash merge to main. Every commit on main must be deployable.
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`.

### Security
- OWASP Top 10 compliance.
- Dependency scanning via GitHub Advanced Security.
- No hardcoded credentials. Use Azure Key Vault + Managed Identity.
- Container images scanned before deploy.

## Azure Infrastructure

- **Resource Group naming:** `rg-{{PROJECT_NAME}}-{env}`
- **Environments:** `dev`, `staging`, `prod`
- **Container Apps Environment** with VNET integration in staging/prod.
- **Log Analytics Workspace** per environment.
- **Application Insights** connected to Container Apps.
- **Azure Container Registry** shared across environments.

## AI & Agent Preferences

- Coding agent: GitHub Copilot (coding agent on GitHub.com for issues, VS Code for local)
- Specs drive all implementation. No code without a spec.
- Each spec task maps to one GitHub issue.
- PRs from coding agents require human review before merge.
- Code quality scanning (CodeQL, Copilot code review) runs on every PR.

## Out of Scope

- Multi-cloud support
- Self-hosted runners (use GitHub-hosted)
- Manual infrastructure provisioning (everything via IaC)
