# BeamFlow CMS Testing Pyramid Overview

This document provides an overview of the testing strategy for the BeamFlow CMS project, explaining the different testing levels and when to use each approach.

## Testing Pyramid Concept

The testing pyramid is a framework that helps teams create a balanced test suite. It visualizes the ideal distribution of tests across different levels of granularity.

![Testing Pyramid](https://martinfowler.com/articles/practical-test-pyramid/testPyramid.png)

For the BeamFlow CMS, we follow this pyramid approach with four distinct layers:

1. **Unit Tests** (Base layer) - Fast tests focused on individual functions and modules
2. **Integration Tests** (Middle layer) - Testing interactions between components
3. **LiveView Tests** (Upper middle layer) - Testing LiveView components without a browser
4. **End-to-End Tests** (Top layer) - Browser-based tests simulating real user interactions

## Characteristics of Each Test Level

As you move up the pyramid:

| Characteristic | Unit Tests | Integration Tests | LiveView Tests | End-to-End Tests |
|----------------|------------|-------------------|----------------|------------------|
| **Speed** | Very fast | Fast | Moderate | Slow |
| **Setup Complexity** | Simple | Moderate | Moderate | Complex |
| **Maintenance Cost** | Low | Medium | Medium | High |
| **Confidence Level** | Low | Medium | High | Very High |
| **Brittleness** | Low | Medium | Medium | High |
| **Specificity** | High | Medium | Medium | Low |
| **Number of Tests** | Many | Some | Some | Few |

## When to Use Each Test Type

### Unit Tests

Unit tests verify that individual units of code (functions, modules) work as expected in isolation.

**Use unit tests for:**
- Pure functions
- Business logic
- Individual context functions
- Validations and schema constraints
- Helpers and utility functions

**Example scenarios:**
- Testing slug generation logic
- Testing post validation rules
- Testing permission checks
- Testing utility functions

### Integration Tests

Integration tests verify that different components work together correctly, testing interactions between contexts, database operations, and cross-module functionality.

**Use integration tests for:**
- Workflows that span multiple contexts
- Database transactions and constraints
- Authorization and policy enforcement
- Cache behavior
- Service interactions

**Example scenarios:**
- Testing post publication workflow
- Testing comment moderation process
- Testing role-based permissions
- Testing database constraints

### LiveView Tests

LiveView tests verify that LiveView components render correctly and handle user interactions properly without requiring a browser.

**Use LiveView tests for:**
- LiveView rendering
- LiveView event handling
- LiveView component interactions
- Form submissions
- UI state transitions

**Example scenarios:**
- Testing post list filtering
- Testing form submissions and validations
- Testing UI updates in response to events
- Testing LiveView hooks and component interactions

### End-to-End Tests

End-to-end tests simulate real user interactions in a browser environment, verifying that all system components work together to deliver the expected user experience.

**Use end-to-end tests for:**
- Complete user journeys
- Multi-step workflows
- Browser-specific behavior
- Real-time features
- Responsive design (visual testing)

**Example scenarios:**
- Testing user registration and login flow
- Testing post creation, editing, and publishing workflow
- Testing role-based access control
- Testing responsive UI behavior

## Recommended Test Distribution

For the BeamFlow CMS, we recommend the following distribution of tests:

- **Unit Tests**: 60-70% of your test suite
- **Integration Tests**: 20-25% of your test suite
- **LiveView Tests**: 10-15% of your test suite
- **End-to-End Tests**: 5-10% of your test suite

## Testing Coverage Targets

| Test Type | Target Coverage | Focus |
|-----------|----------------|-------|
| **Unit Tests** | 90%+ code coverage | Every module, all business logic |
| **Integration Tests** | Key workflows | Context interactions, authorization |
| **LiveView Tests** | All LiveView modules | Events, rendering, form handling |
| **End-to-End Tests** | Critical user journeys | Core workflows, role-based access |

## Test Organization

We use ExUnit tags to organize tests and allow selective running:

```elixir
# Unit test
@tag :unit
test "generates correct slug", do: # ...

# Integration test
@tag :integration
test "publishes post and creates activity", do: # ...

# LiveView test
@tag :liveview
test "filters posts by status", do: # ...

# E2E test
@tag :e2e
test "author can create and edit posts", do: # ...
```

This allows running specific test types:

```bash
# Run only unit tests
mix test --only unit

# Run only E2E tests
mix test --only e2e

# Run all except E2E tests (faster for development)
mix test --exclude e2e
```

## CI Pipeline Integration

Our CI pipeline runs tests in stages, with faster tests running first:

1. **Static Analysis**: Code formatting and Credo checks
2. **Unit Tests**: Run all unit tests
3. **Integration Tests**: Run all integration tests
4. **LiveView Tests**: Run all LiveView tests 
5. **End-to-End Tests**: Run all end-to-end tests

This approach provides fast feedback for common issues while still ensuring comprehensive testing.

## Detailed Testing Guides

For detailed examples and best practices, refer to our specific testing guides:

1. [Unit Testing Guide](unit-testing-guide.md)
2. [Integration Testing Guide](integration-testing-guide.md)
3. [LiveView Testing Guide](liveview-testing-guide.md)
4. [End-to-End Testing Guide](e2e-testing-guide.md)