# Copilot Instructions

## Project Context

This project follows an AI-led SDLC using spec-driven development. All implementation work is guided by specifications in the `.specify/` directory. The project constitution (`.specify/constitution.md`) defines the tech stack, coding standards, and architecture principles.

## How to Work in This Repository

1. **Always read the constitution first.** Before making any changes, read `.specify/constitution.md` to understand the project's standards and constraints.

2. **Find the relevant spec.** Every task should trace back to a spec in `specs/`. Read the spec's `requirements.md`, `plan.md`, and `tasks.md` before implementing.

3. **Implement one task at a time.** Each task in `tasks.md` is a self-contained unit of work. Complete it fully (including tests) before moving to the next.

4. **Follow the testing strategy.** Write tests alongside or before implementation. Unit test coverage must be at least 80%. Run all tests before committing.

5. **Use conventional commits.** Format: `feat: description`, `fix: description`, `test: description`, etc. Reference the spec task ID in the commit body.

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

- Keep PRs focused on a single spec task.
- Include screenshots for UI changes.
- Ensure CI passes before requesting review.
- Reference the GitHub issue number in the PR description.
