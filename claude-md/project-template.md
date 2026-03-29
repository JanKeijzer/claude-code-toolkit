# Project CLAUDE.md

## Project Overview

<!-- What does this project do? Who is it for? -->

## Tech Stack

<!-- Language, framework, database, test framework, etc. -->

## Project Structure

<!-- Key directories and their purpose, e.g.:
- src/          → application source code
- tests/        → test suite
- migrations/   → database migrations
-->

## Development Commands

<!-- How to run, test, validate, and lint the project, e.g.:
- Run:      `make run` or `python manage.py runserver`
- Test:     `pytest tests/ -v`
- Lint:     `ruff check .`
- Validate: `make validate`
-->

## API Conventions

<!-- If applicable: REST/GraphQL, authentication, versioning, error format, etc. -->

## Database Conventions

<!-- If applicable: naming conventions, migration workflow, ORM patterns, etc. -->

## Frontend Standards

<!-- If applicable, uncomment and adjust:
- Loading indicators only after >500ms delay (debounce to prevent flickering)
- All user-facing text via translation keys (`t('key')`), never hardcoded strings
- When using an API client with baseURL: use relative URLs (prevent double prefixes)
-->

## Project-Specific Patterns

<!-- Conventions unique to this project, e.g.:
- All services inherit from BaseService
- Use dependency injection via constructor
- Background jobs go in jobs/ directory
-->

## Deployment Notes

<!-- How the project is deployed, environment variables, CI/CD notes, etc. -->

## Integration Verification

<!-- Optional: Configure runtime verification for /verify, /implement, and /implement-epic.
     Remove this section if the project doesn't use Docker or doesn't need runtime checks.

After implementation, verify Docker containers start correctly if any of these
file patterns were modified:

| Pattern | Containers affected |
|---------|-------------------|
| `backend/Dockerfile*` | all containers |
| `docker-compose*` | all containers |
| `requirements*.txt` or `pyproject.toml` | api, worker |
| `package.json` | frontend |

### Verification config
- Container prefix: myproject_
- Health check timeout: 120
- Rebuild command: docker compose up -d --build
- Health check: ~/.claude/bin/docker-health-check.sh --filter myproject_ --timeout 120
- Smoke test: ~/.claude/bin/smoke-test.sh http://localhost:8080
- Migrate command: docker exec myproject_api alembic upgrade head
- Frontend URL: http://localhost:3000

### Trigger rules
- /implement: only run when modified files match the patterns above
- /implement-epic: ALWAYS run full verification
-->
