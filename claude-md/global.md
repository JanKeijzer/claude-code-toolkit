# Global CLAUDE.md

## General Preferences

- Code comments in English
- Communication in Dutch (unless context requires otherwise)
- Commit messages in English, concise and descriptive
- `docker compose` (with space), never `docker-compose` (with hyphen)

## Test Quality Policy

- Tests must verify real behavior through the full stack where possible
- Mocks are ONLY acceptable for external services (third-party APIs, email, payment providers)
- If you mock a database query or internal service, justify WHY in a code comment
- NEVER mock the thing you are testing
- Prefer integration-style tests over heavily mocked unit tests
- Fixtures must reflect realistic data, not minimal placeholders
- Include edge cases in fixture data (empty strings, unicode, boundary values)
- If a fixture represents a user, give it realistic attributes — not `name="test"`, `email="test@test.com"`
- For every test, ask: "If someone subtly breaks this feature, will THIS test actually fail?"
- For every test, ask: "Am I testing that the code works, or just that it runs without errors?"

## Anti-Patterns (always avoid)

- Assume a model has attributes without reading the model file
- Write tests that import non-existent classes
- Claim tests pass without showing actual test output
- Skip validation because "it should work"
- Commit code that hasn't been tested
- Mock internal code just to make tests easier to write
- Create fixtures with placeholder data like `name="test"` or `value=123`
- Write tests that only verify "no exception was raised"

## Code Quality

- Before using model attributes, verify they exist (grep/search)
- Before importing classes, verify they exist
- Follow existing patterns in the codebase — read before writing
- If ANY verification fails, STOP and reassess
- DRY: check if similar logic already exists before implementing; create shared functions instead of duplicating
- No magic strings/numbers: use constants, enums, or configuration for all business logic values
- Remove obsolete code always. Never keep old files "just in case"

## Documentation Standards

- Focus on current purpose, not implementation history
- Include usage guidance and critical warnings
- No historical changelogs in code documentation

## Frontend Standards

- Loading indicators only after >500ms delay (debounce to prevent flickering)
- All user-facing text via translation keys (`t('key')`), never hardcoded strings
- When using an API client with baseURL: use relative URLs (prevent double prefixes)

## Claude Code Workarounds

- Bash tool: always save API responses to a file first, then read the file
- Never use command substitution with pipes for API data
- Never use heredoc in Bash commands (not `cat << EOF`, not in git commit). Multi-line Bash commands don't match permission patterns like `Bash(git *)`. Instead: use the Write tool to write to `/tmp/`, then reference the file in Bash (e.g., `git commit -F /tmp/commit-msg`, `gh issue create --body-file /tmp/issue-body.md`).
