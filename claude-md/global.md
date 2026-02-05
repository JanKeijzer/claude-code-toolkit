# Global CLAUDE.md

## General Preferences

- Code comments in English
- Communication in Dutch (unless context requires otherwise)
- Commit messages in English, concise and descriptive

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
