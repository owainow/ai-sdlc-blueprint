# Copilot Instructions

## Project Context

This project follows an **AI-led SDLC** using spec-driven development. Every change — whether initiated from Copilot CLI, the GitHub coding agent, or an IDE — must follow this process.

The source of truth for project standards is `.specify/constitution.md`. Read it before doing anything.

## The SDLC Flow

```
Idea → Spec Kit (specify → plan → tasks) → speckit-to-issue → GitHub Issues → Coding Agent → PR → CI/CD → Azure
```

### For the developer (Copilot CLI / local)

1. **Specify:** Describe what you want to build. Use Spec Kit to generate requirements, a plan, and tasks.
2. **Create issues:** Run `speckit-to-issue create specs/NNN-feature/tasks.md --assign-copilot` to push tasks to GitHub.
3. **Let the coding agent work:** The GitHub coding agent picks up assigned issues, creates branches, and opens PRs.
4. **Review:** PRs get AI quality review + human review. Leave comments for the coding agent to iterate.
5. **Merge → Deploy:** CI/CD handles the rest. GitHub Actions builds, pushes to ACR, deploys to Azure Container Apps.

### For the coding agent (GitHub.com)

When assigned an issue:
1. Read `.specify/constitution.md` for project standards.
2. Find the relevant spec in `specs/` — read `requirements.md`, `plan.md`, and `tasks.md`.
3. Implement exactly one task per issue. Follow the acceptance criteria.
4. Write tests alongside implementation. Minimum 80% unit test coverage.
5. Use conventional commits: `feat:`, `fix:`, `test:`, `chore:`, `docs:`. Reference the task ID.

## Code Standards

- TypeScript: strict mode, no `any`, ESLint clean.
- Python: type hints, Ruff clean, mypy strict.
- All API endpoints must have OpenAPI documentation.
- No hardcoded secrets — use environment variables or Azure Key Vault.
- Container images should use multi-stage Docker builds.

## Azure Specifics

- All infrastructure is defined in `infra/` using Bicep.
- Use managed identities for service-to-service communication.
- Application Insights is pre-configured — use structured logging.
- Health check endpoints: `/health` (liveness), `/ready` (readiness).

## PR Guidelines

- One task = one issue = one PR. Keep changes atomic.
- Include screenshots for UI changes.
- Ensure CI passes before requesting review.
- Reference the GitHub issue number in the PR description.

## Key Paths

| Path | Purpose |
|---|---|
| `.specify/constitution.md` | Project standards, tech stack, architecture constraints |
| `specs/` | Specifications, plans, and task breakdowns |
| `infra/` | Bicep templates for Azure infrastructure |
| `.github/workflows/` | CI/CD and PR sandbox pipelines |
| `src/` | Application source code |
| `tests/` | Test files |
