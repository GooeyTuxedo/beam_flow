# BeamFlow CMS Coding Standards

This document provides an overview of the coding standards established for the BeamFlow CMS project. It serves as an entry point to more detailed guides on specific aspects of the codebase.

## Purpose

These coding standards aim to:

1. Ensure consistency across the codebase
2. Promote maintainability and readability
3. Establish security and performance best practices
4. Reduce technical debt
5. Facilitate onboarding of new developers

## Core Standards Documents

The following documents provide detailed guidelines for different aspects of development:

1. [Elixir Style Guide](./elixir-style-guide.md) - General Elixir coding conventions
2. [Phoenix LiveView Best Practices](./phoenix-liveview-guide.md) - LiveView development standards
3. [Context Design and Boundaries](./contexts-boundaries-guide.md) - Maintaining proper context separation
4. [Ecto Best Practices](./ecto-best-practices.md) - Database interaction standards
5. [Observability Standards](./observability-guide.md) - Logging, metrics, and tracing guidelines
6. [Security Best Practices](./security-best-practices.md) - Security standards for all development

## Development Workflow

All new development should follow these steps:

1. **Planning**
   - Document requirements with clear acceptance criteria
   - Design and architecture planning
   - Security and performance considerations

2. **Implementation**
   - Follow relevant coding standards
   - Implement incremental changes
   - Add appropriate tests (unit, integration, etc.)
   - Include observability instrumentation

3. **Review**
   - Code review against standards
   - Security review for sensitive features
   - Performance review for critical paths

4. **Testing**
   - Ensure test coverage requirements are met
   - Verify functionality across all targeted environments
   - Validate security and performance requirements

5. **Deployment**
   - Use CI/CD pipeline for consistent deployments
   - Monitor for issues post-deployment
   - Document any necessary operational procedures

## Key Principles

### Context Boundaries

BeamFlow is organized into distinct contexts:

- **Accounts** - User management, authentication, and authorization
- **Content** - Posts, categories, tags, and media management
- **Engagement** - Comments, analytics, and user interactions
- **Site** - Site settings, themes, and configuration

Always respect context boundaries by:

- Using the public API of contexts
- Avoiding direct access to internal functions or schemas
- Keeping implementation details private

### Testing Requirements

All new code must include appropriate tests:

- **Unit Tests** - For individual functions and modules
- **Integration Tests** - For cross-context workflows
- **LiveView Tests** - For LiveView components
- **End-to-End Tests** - For critical user journeys

Refer to our [Testing Overview](../testing/overview.md) for detailed guidance.

### Observability

All new features should include:

- **Structured Logging** - For important business events and errors
- **Metrics** - For performance and usage tracking
- **Traces** - For complex operations that span multiple contexts

### Security

All new code must adhere to security best practices:

- **Input Validation** - Validate and sanitize all user input
- **Authentication** - Use secure authentication mechanisms
- **Authorization** - Implement proper permission checks
- **Data Protection** - Safeguard sensitive data

## Development Environment Setup

For consistent development, ensure your environment is properly configured:

1. **Code Formatting**
   - Configure your editor to use the project's formatter settings
   - Run `mix format` before committing changes

2. **Linting**
   - Run `mix credo` to check for code style issues
   - Address all warnings and errors before submitting code

3. **Testing**
   - Run tests with `mix test` regularly during development
   - Run `mix coveralls` to check test coverage

4. **Security Checks**
   - Run `mix sobelow` to scan for security vulnerabilities
   - Address all security issues before deployment

## Getting Help

If you're unsure about any aspect of these coding standards:

1. Consult the relevant detailed guide
2. Ask for guidance in the team communication channels
3. Request a code review from a more experienced team member
4. Suggest improvements to standards if they're unclear or incomplete

## Standards Maintenance

These coding standards are living documents. If you identify areas for improvement:

1. Discuss proposed changes with the team
2. Document the rationale for changes
3. Update relevant standards documents
4. Communicate changes to the entire development team

## Resources

- [Phoenix Framework Documentation](https://hexdocs.pm/phoenix/overview.html)
- [Elixir Documentation](https://hexdocs.pm/elixir/Kernel.html)
- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)