# Contributing to BeamFlow CMS

Thank you for considering contributing to BeamFlow CMS! This document outlines the process for contributing to the project and our Git workflow.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Git Workflow](#git-workflow)
- [Development Environment](#development-environment)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

We expect all contributors to follow our Code of Conduct. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## Git Workflow

We follow a structured Git workflow to maintain code quality and ensure smooth collaboration:

### Branch Structure

```
main             # Production-ready code
├── dev          # Integration branch for active development
│   ├── feature/* # Feature branches
│   ├── fix/*     # Bug fix branches
│   ├── refactor/* # Code refactoring branches
│   └── docs/*    # Documentation branches
└── release/*    # Release branches
```

### Branch Naming Convention

- `feature/short-description` - For new features
- `fix/issue-reference` - For bug fixes
- `refactor/component-name` - For code refactoring
- `docs/topic` - For documentation updates

Example: `feature/markdown-editor` or `fix/GH-42-login-error`

### Commit Message Guidelines

Follow the Conventional Commits specification:

- `feat:` - New feature
- `fix:` - Bug fix  
- `docs:` - Documentation changes
- `style:` - Formatting changes
- `refactor:` - Code refactoring
- `test:` - Adding or modifying tests
- `chore:` - Maintenance tasks
- `perf:` - Performance improvements
- `ci:` - CI configuration changes

Example: `feat(markdown-editor): implement real-time preview`

## Development Environment

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/beam-flow.git
   cd beam-flow
   ```

2. **Set up Docker environment**
   ```bash
   docker-compose up -d
   ```

3. **Install dependencies**
   ```bash
   mix deps.get
   ```

4. **Run tests to verify setup**
   ```bash
   mix test
   ```

## Making Changes

1. **Create a feature branch from dev**
   ```bash
   git checkout dev
   git pull
   git checkout -b feature/your-feature-name
   ```

2. **Make small, focused commits**
   ```bash
   git add <files>
   git commit -m "feat: implement feature X"
   ```

3. **Stay in sync with dev branch**
   ```bash
   git checkout dev
   git pull
   git checkout feature/your-feature-name
   git rebase dev
   ```

4. **Push your changes**
   ```bash
   git push -u origin feature/your-feature-name
   ```

## Pull Request Process

1. **Create a Pull Request to dev branch**
   - Use the PR template
   - Reference related issues
   - Assign reviewers

2. **Ensure CI checks pass**
   - Code formatting (`mix format --check-formatted`)
   - Linting with Credo (`mix credo --strict`)
   - Security checks with Sobelow (`mix sobelow --config`)
   - Test suite (`mix test`)

3. **Address review feedback**
   ```bash
   git add <files>
   git commit -m "fix: address PR feedback"
   git push
   ```

4. **Squash commits if needed**
   ```bash
   git rebase -i HEAD~3  # Squash last 3 commits
   git push --force-with-lease
   ```

5. **Merge requirements**
   - At least 1 approval for dev branch PRs
   - 2 approvals for main branch PRs
   - All CI checks must pass
   - Conflicts must be resolved

## Coding Standards

Please adhere to our coding standards:

- **Elixir Style**: Follow our [Elixir Style Guide](./docs/coding-standards/elixir-style-guide.md)
- **Phoenix LiveView**: Follow our [Phoenix LiveView Best Practices](./docs/coding-standards/phoenix-liveview-guide.md)
- **Contexts**: Respect [Context Boundaries](./docs/coding-standards/contexts-boundaries-guide.md)
- **Ecto**: Follow our [Ecto Best Practices](./docs/coding-standards/ecto-best-practices.md)
- **Observability**: Implement [Observability Standards](./docs/coding-standards/observability-guide.md)
- **Security**: Adhere to [Security Best Practices](./docs/coding-standards/security-best-practices.md)

## Testing Requirements

All contributions must include appropriate tests:

- **Unit Tests**: For individual functions and modules
- **Integration Tests**: For workflows spanning multiple contexts
- **LiveView Tests**: For LiveView components
- **End-to-End Tests**: For critical user journeys

See our [Testing Overview](./docs/testing/overview.md) for detailed guidance.

Test coverage requirements:
- New code should have at least 90% coverage
- Bug fixes must include a test that reproduces the issue

## Documentation

Update documentation for any new features or changes:

- Update relevant README or guide files
- Add inline documentation (moduledocs and function docs)
- Include examples where appropriate
- Document any new configuration options

## Release Process

1. **Create a release branch**
   ```bash
   git checkout main
   git pull
   git checkout -b release/v1.0.0
   ```

2. **Merge dev into release branch**
   ```bash
   git merge dev --no-ff -m "chore: prepare release v1.0.0"
   ```

3. **Create a PR from release branch to main**
   - Requires 2 approvals
   - All checks must pass

4. **Tag the release on main**
   ```bash
   git checkout main
   git pull
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push --tags
   ```

## Getting Help

If you have questions or need help, you can:
- Open an issue with your question
- Reach out on the project's communication channel
- Contact the core team members listed in the README

Thank you for contributing to BeamFlow CMS!