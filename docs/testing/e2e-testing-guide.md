# BeamFlow CMS End-to-End Testing Guide

This guide focuses on end-to-end testing for the BeamFlow CMS project using Wallaby, providing examples and best practices for testing complete user workflows in a real browser environment.

## When to Use End-to-End Tests

End-to-end tests are ideal for:

* Testing complete user journeys
* Testing multi-step workflows
* Testing browser-specific behavior
* Testing real-time features like LiveView updates
* Testing responsive design (visual testing)
* Testing features that require JavaScript execution

## End-to-End Test Examples

### Setting Up End-to-End Test Infrastructure

First, let's set up the testing infrastructure:

```elixir
# test/support/feature_case.ex
defmodule BeamFlow.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature
      
      import BeamFlow.Factory
      import BeamFlowWeb.Gettext
      import BeamFlow.FeatureHelpers
      
      alias BeamFlowWeb.Router.Helpers, as: Routes
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(BeamFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(BeamFlow.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    
    {:ok, session: session}
  end
end

# test/support/feature_helpers.ex
defmodule BeamFlow.FeatureHelpers do
  use Wallaby.DSL
  
  # Login helper
  def login_as(session, %{email: email, password: password, role: _role}) do
    session
    |> visit(Routes.user_session_path(BeamFlowWeb.Endpoint, :new))
    |> fill_in(Query.text_field("Email"), with: email)
    |> fill_in(Query.text_field("Password"), with: password)
    |> click(Query.button("Sign in"))
    |> assert_has(Query.css(".dashboard-header"))
  end
  
  # Dashboard navigation helper
  def navigate_to_posts(session) do
    session
    |> click(Query.link("Posts"))
    |> assert_has(Query.css(".posts-listing"))
  end
  
  # Create post helper
  def create_new_post(session, %{title: title, content: content}) do
    session
    |> click(Query.link("New Post"))
    |> fill_in(Query.text_field("Title"), with: title)
    |> fill_in(Query.text_field("Content"), with: content)
    |> click(Query.button("Save"))
    |> assert_has(Query.css(".alert-success"))
  end
end
```

### Testing User Authentication Flow

```elixir
# test/beam_flow_web/features/authentication_test.exs
defmodule BeamFlowWeb.Features.AuthenticationTest do
  use BeamFlow.FeatureCase, async: true
  import Wallaby.Query

  test "user registration and login flow", %{session: session} do
    email = "newuser@example.com"
    password = "password123"

    session
    |> visit("/register")
    |> assert_has(css("h1", text: "Register"))
    
    # Fill registration form
    |> fill_in(text_field("Email"), with: email)
    |> fill_in(text_field("Password"), with: password)
    |> fill_in(text_field("Password confirmation"), with: password)
    |> click(button("Register"))
    
    # Should redirect to login after registration
    |> assert_has(css(".alert-info", text: "Account created successfully"))
    |> assert_has(css("h1", text: "Log In"))
    
    # Login with new credentials
    |> fill_in(text_field("Email"), with: email)
    |> fill_in(text_field("Password"), with: password)
    |> click(button("Log in"))
    
    # Should be logged in now
    |> assert_has(css(".alert-info", text: "Welcome back"))
    |> assert_has(css(".user-email", text: email))
    
    # Logout
    |> click(link("Logout"))
    |> assert_has(css(".alert-info", text: "Logged out successfully"))
    |> assert_has(css("h1", text: "Log In"))
  end

  test "login with invalid credentials shows error", %{session: session} do
    session
    |> visit("/login")
    |> fill_in(text_field("Email"), with: "wrong@example.com")
    |> fill_in(text_field("Password"), with: "wrongpassword")
    |> click(button("Log in"))
    
    # Should show error message
    |> assert_has(css(".alert-danger", text: "Invalid email or password"))
  end
end
```

### Testing Post Management Workflow

```elixir
# test/beam_flow_web/features/post_management_test.exs
defmodule BeamFlowWeb.Features.PostManagementTest do
  use BeamFlow.FeatureCase, async: true
  import Wallaby.Query
  
  setup do
    # Create a test user
    {:ok, user} = BeamFlow.Accounts.create_user(%{
      email: "author@example.com",
      password: "password123",
      role: "author"
    })
    
    %{user: user}
  end
  
  test "author can create and edit posts", %{session: session, user: user} do
    post_title = "Test Post Title"
    post_content = "This is the content of my test post."
    updated_title = "Updated Post Title"
    
    session
    # Login
    |> visit("/login")
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: "password123")
    |> click(button("Log in"))
    
    # Navigate to posts
    |> click(link("Posts"))
    |> assert_has(css("h1", text: "My Posts"))
    
    # Create new post
    |> click(link("New Post"))
    |> assert_has(css("h1", text: "New Post"))
    |> fill_in(text_field("Title"), with: post_title)
    |> fill_in(textarea("Content"), with: post_content)
    |> click(button("Save"))
    
    # Should show success message
    |> assert_has(css(".alert-info", text: "Post created successfully"))
    
    # Post should appear in the list
    |> visit("/author/posts")
    |> assert_has(link(post_title))
    
    # Edit the post
    |> click(link(post_title))
    |> click(link("Edit"))
    |> fill_in(text_field("Title"), with: updated_title)
    |> click(button("Save"))
    
    # Should show updated title
    |> assert_has(css("h1", text: updated_title))
    
    # Delete the post
    |> click(link("Delete"))
    |> accept_dialog() # Confirm the deletion dialog
    
    # Should redirect to posts list without the deleted post
    |> assert_has(css(".alert-info", text: "Post deleted successfully"))
    |> refute_has(link(updated_title))
  end
  
  test "preview post while editing", %{session: session, user: user} do
    post_title = "Preview Test"
    post_content = "# Heading\n\nThis is a _markdown_ test."
    
    session
    # Login
    |> visit("/login")
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: "password123")
    |> click(button("Log in"))
    
    # Create new post
    |> visit("/author/posts/new")
    |> fill_in(text_field("Title"), with: post_title)
    |> fill_in(textarea("Content"), with: post_content)
    
    # Check preview tab
    |> click(link("Preview"))
    
    # Verify markdown rendering
    |> assert_has(css("h1", text: "Heading"))
    |> assert_has(css("em", text: "markdown"))
    
    # Return to edit tab and submit
    |> click(link("Edit"))
    |> click(button("Save"))
    
    # Verify saved content is properly rendered
    |> assert_has(css("h1", text: "Heading"))
    |> assert_has(css("em", text: "markdown"))
  end
end
```

### Testing Role-Based Access Control

```elixir
# test/beam_flow_web/features/role_permissions_test.exs
defmodule BeamFlowWeb.Features.RolePermissionsTest do
  use BeamFlow.FeatureCase, async: true
  import Wallaby.Query
  
  setup do
    # Create test users with different roles
    {:ok, admin} = BeamFlow.Accounts.create_user(%{
      email: "admin@example.com",
      password: "password123",
      role: "admin"
    })
    
    {:ok, editor} = BeamFlow.Accounts.create_user(%{
      email: "editor@example.com",
      password: "password123",
      role: "editor"
    })
    
    {:ok, author} = BeamFlow.Accounts.create_user(%{
      email: "author@example.com",
      password: "password123",
      role: "author"
    })
    
    # Create a post by the author
    {:ok, author_post} = BeamFlow.Content.create_post(author, %{
      title: "Author Post",
      content: "This is a post by the author.",
      status: "draft"
    })
    
    %{
      admin: admin,
      editor: editor,
      author: author,
      author_post: author_post
    }
  end
  
  test "admin can view and edit all posts", %{session: session, admin: admin, author_post: post} do
    session
    # Login as admin
    |> visit("/login")
    |> fill_in(text_field("Email"), with: admin.email)
    |> fill_in(text_field("Password"), with: "password123")
    |> click(button("Log in"))
    
    # Should see admin dashboard
    |> assert_has(css("h1", text: "Admin Dashboard"))
    
    # Navigate to all posts
    |> click(link("All Posts"))
    |> assert_has(link(post.title))
    
    # View post
    |> click(link(post.title))
    |> assert_has(css("h1", text: post.title))
    
    # Should have edit option
    |> assert_has(link("Edit"))
    
    # Should have publish option (since post is draft)
    |> assert_has(button("Publish"))
    
    # Can publish the post
    |> click(button("Publish"))
    |> assert_has(css(".alert-info", text: "Post published successfully"))
    |> assert_has(css(".status-badge", text: "Published"))
  end
  
  test "editor can publish but not delete posts", %{session: session, editor: editor, author_post: post} do
    session
    # Login as editor
    |> visit("/login")
    |> fill_in(text_field("Email"), with: editor.email)
    |> fill_in(text_field("Password"), with: "password123")
    |> click(button("Log in"))
    
    # Should see editor dashboard
    |> assert_has(css("h1", text: "Editor Dashboard"))
    
    # Navigate to all posts
    |> click(link("Content"))
    |> click(link("All Posts"))
    |> assert_has(link(post.title))
    
    # View and publish post
    |> click(link(post.title))
    |> assert_has(button("Publish"))
    |> click(button("Publish"))
    |> assert_has(css(".status-badge", text: "Published"))
    
    # Should not have delete option
    |> refute_has(link("Delete"))
  end
  
  test "author can only view and edit own posts", %{session: session, author: author, author_post: post} do
    # Create another author with a post
    {:ok, other_author} = BeamFlow.Accounts.create_user(%{
      email: "other.author@example.com",
      password: "password123",
      role: "author"
    })
    
    {:ok, other_post} = BeamFlow.Content.create_post(other_author, %{
      title: "Other Author Post",
      content: "This is a post by another author.",
      status: "draft"
    })
    
    session
    # Login as author
    |> visit("/login")
    |> fill_in(text_field("Email"), with: author.email)
    |> fill_in(text_field("Password"), with: "password123")
    |> click(button("Log in"))
    
    # Should see author dashboard
    |> assert_has(css("h1", text: "Author Dashboard"))
    
    # Navigate to my posts
    |> click(link("My Posts"))
    |> assert_has(link(post.title))
    
    # Should not see other author's post
    |> refute_has(link(other_post.title))
    
    # Can edit own post
    |> click(link(post.title))
    |> assert_has(link("Edit"))
    
    # Should not have publish option
    |> refute_has(button("Publish"))
    
    # Try to access other author's post directly (should be denied)
    |> visit("/author/posts/#{other_post.id}")
    |> assert_has(css(".alert-danger", text: "You are not authorized"))
  end
end
```

### Testing Responsive Interface

```elixir
# test/beam_flow_web/features/responsive_interface_test.exs
defmodule BeamFlowWeb.Features.ResponsiveInterfaceTest do
  use BeamFlow.FeatureCase, async: true
  import Wallaby.Query
  
  setup do
    {:ok, user} = BeamFlow.Accounts.create_user(%{
      email: "user@example.com",
      password: "password123",
      role: "admin"
    })
    
    %{user: user}
  end
  
  test "dashboard adapts to mobile viewport", %{session: session, user: user} do
    session
    # Login
    |> visit("/login")
    |> fill_in(text_field("Email"), with: user.email)
    |> fill_in(text_field("Password"), with: "password123")
    |> click(button("Log in"))
    
    # Check desktop layout - sidebar should be visible
    |> assert_has(css(".sidebar"))
    |> assert_has(css(".main-content"))
    |> refute_has(css(".mobile-menu-button"))
    
    # Resize to mobile viewport
    |> resize_window(375, 667)
    
    # Sidebar should be hidden, mobile menu button visible
    |> refute_visible(css(".sidebar"))
    |> assert_has(css(".mobile-menu-button"))
    
    # Open mobile menu
    |> click(css(".mobile-menu-button"))
    
    # Sidebar should now be visible
    |> assert_visible(css(".sidebar"))
    
    # Close by clicking outside
    |> click(css(".main-content"))
    
    # Sidebar should be hidden again
    |> refute_visible(css(".sidebar"))
  end
end
```

## End-to-End Testing Best Practices

### 1. Test Complete User Journeys

Focus on testing complete workflows from start to finish:

- Registration and onboarding
- Content creation and publishing
- Admin workflows
- User interactions with published content

```elixir
test "complete publishing workflow", %{session: session} do
  # Login as author
  # Create draft post
  # Login as editor
  # Review and publish post
  # Verify post appears on public site
  # Add comment as a reader
  # Verify comment appears
end
```

### 2. Prioritize Critical Paths

Identify and prioritize the most important user flows:

- Authentication and authorization
- Core content management
- Key user-facing features
- Revenue-generating functionality

### 3. Use Helpers for Common Actions

Create helpers for common testing actions to keep tests readable:

```elixir
defmodule BeamFlow.FeatureHelpers do
  use Wallaby.DSL
  
  def login_as(session, user) do
    # Login implementation
  end
  
  def create_post(session, attrs) do
    # Post creation implementation
  end
  
  def publish_post(session, post) do
    # Post publishing implementation
  end
end
```

### 4. Test Different Devices and Viewports

Test responsive behavior on different screen sizes:

```elixir
test "responsive behavior", %{session: session} do
  # Test desktop view (default)
  session
  |> visit("/posts")
  |> assert_has(css(".desktop-layout"))
  
  # Test tablet view
  |> resize_window(768, 1024)
  |> assert_has(css(".tablet-layout"))
  
  # Test mobile view
  |> resize_window(375, 667)
  |> assert_has(css(".mobile-layout"))
end
```

### 5. Test Role-Based Access

Test with different user roles to verify proper access controls:

```elixir
test "role-based access controls", %{session: session} do
  # Test as admin
  session
  |> login_as(admin)
  |> visit("/admin/settings")
  |> assert_has(css("h1", text: "Admin Settings"))
  
  # Test as editor
  |> logout()
  |> login_as(editor)
  |> visit("/admin/settings")
  |> assert_has(css(".access-denied"))
end
```

### 6. Handle Asynchronous Operations

Handle AJAX and async operations with proper waiting:

```elixir
test "async operations", %{session: session} do
  session
  |> visit("/dashboard")
  |> click(button("Load Data"))
  
  # Wait for specific element to appear
  |> assert_has(css(".data-loaded", count: 1, text: "Data Loaded"))
  
  # Or use a specific wait helper
  |> wait_for(fn session ->
    has_text?(session, "Data Loaded")
  end)
end
```

### 7. Test Error States

Test error handling and recovery:

```elixir
test "error handling", %{session: session} do
  session
  |> visit("/posts/new")
  |> fill_in(text_field("Title"), with: "")  # Invalid data
  |> click(button("Save"))
  
  # Verify error is shown
  |> assert_has(css(".error-message", text: "Title can't be blank"))
  
  # Fix the error and try again
  |> fill_in(text_field("Title"), with: "Valid Title")
  |> click(button("Save"))
  
  # Verify success
  |> assert_has(css(".success-message"))
end
```

### 8. Use Screenshots for Debugging

Take screenshots during test failures to help diagnose issues:

```elixir
# In your test case
rescue e ->
  take_screenshot(session, name: "failure-#{:os.system_time(:millisecond)}")
  reraise e, __STACKTRACE__
```

## Wallaby Configuration

### Basic Setup

```elixir
# In config/test.exs
config :beam_flow, :sandbox, Ecto.Adapters.SQL.Sandbox

config :wallaby,
  driver: Wallaby.Chrome,
  chrome: [
    headless: true
  ],
  base_url: "http://localhost:4002",
  screenshot_dir: "test/screenshots"

config :beam_flow, BeamFlowWeb.Endpoint,
  http: [port: 4002],
  server: true
```

### Chrome Options

Configure Chrome for different testing needs:

```elixir
# Headless mode (default for CI)
config :wallaby,
  chrome: [
    headless: true
  ]

# Non-headless for visual debugging
config :wallaby,
  chrome: [
    headless: false
  ]

# With specific window size
config :wallaby,
  chrome: [
    headless: true,
    window_size: "1280,720"
  ]

# With specific capabilities
config :wallaby,
  chrome: [
    capabilities: %{
      "goog:chromeOptions" => %{
        "args" => [
          "--no-sandbox",
          "--disable-dev-shm-usage",
          "--disable-gpu"
        ]
      }
    }
  ]
```

### Wallaby DSL Tips

Useful Wallaby DSL functions:

```elixir
# Navigating
visit(session, "/path")

# Finding elements
element(session, ".selector")
elements(session, ".selector")

# Interacting
click(session, Query.button("Click me"))
fill_in(session, Query.text_field("Name"), with: "John Doe")
clear(session, Query.text_field("Name"))
check(session, Query.checkbox("Accept terms"))
select(session, Query.select("Country"), option: "Canada")

# Assertions
assert_has(session, Query.css(".element"))
refute_has(session, Query.css(".element"))
assert_text(session, "Expected text")
has_value?(session, Query.text_field("Name"), "John Doe")

# Waiting
session
|> visit("/page")
|> assert_has(Query.css(".loaded", count: 1))

# Custom wait
wait_for(session, 5_000, fn session ->
  has_text?(session, "Expected text")
end)

# Taking screenshots
take_screenshot(session, name: "screenshot-name")
```

## Integrating with CI Pipeline

### GitHub Actions Configuration

```yaml
# .github/workflows/e2e-tests.yml
name: End-to-End Tests

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main, dev ]

jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    services:
      db:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_USER: postgres
          POSTGRES_DB: beam_flow_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '26.2'
          elixir-version: '1.18.0'
      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-
      - name: Install dependencies
        run: mix deps.get
      - name: Setup ChromeDriver
        uses: nanasess/setup-chromedriver@v2
      - name: Start ChromeDriver
        run: |
          chromedriver --port=9515 &
          echo "ChromeDriver started"
      - name: Run E2E tests
        run: |
          mix test --only e2e
      - name: Upload Screenshots (on failure)
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: test-screenshots
          path: test/screenshots
```

## Test Coverage Guidelines

For end-to-end tests, aim for:

- All critical user journeys have E2E tests
- All user roles and their permissions are tested
- Key workflows (creation, editing, publishing) are covered
- Different viewport sizes are tested for responsive design

## Tagged Tests

Use tags to organize your E2E tests:

```elixir
@tag :e2e
@tag :auth
test "user registration flow", do: # ...

@tag :e2e
@tag :content
test "post creation workflow", do: # ...
```

Run specific tagged E2E tests:

```bash
# Run all E2E tests
mix test --only e2e

# Run only authentication E2E tests
mix test --only e2e --only auth

# Run E2E tests excluding slow ones
mix test --only e2e --exclude slow
```

## Troubleshooting Common Issues

### Element Not Found

If tests fail with "Element not found" errors:

1. Check if there's a timing issue:
   ```elixir
   # Use a longer wait time
   assert_has(session, Query.css(".element", count: 1), fn query, _session ->
     query
     |> Query.put_option(:wait, 5_000) # Wait up to 5 seconds
   end)
   ```

2. Verify the element is visible:
   ```elixir
   # Ensure the element is visible
   assert_visible(session, Query.css(".element"))
   ```

3. Check if the element is inside a frame:
   ```elixir
   # Switch to a frame
   session
   |> focus_frame(Query.css("iframe"))
   |> assert_has(Query.css(".element-inside-frame"))
   ```

### Database Conflicts

If you see database conflicts:

1. Ensure you're using the shared mode correctly:
   ```elixir
   # In your setup
   :ok = Ecto.Adapters.SQL.Sandbox.checkout(BeamFlow.Repo)
   Ecto.Adapters.SQL.Sandbox.mode(BeamFlow.Repo, {:shared, self()})
   ```

2. Make sure you're passing metadata:
   ```elixir
   metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(BeamFlow.Repo, self())
   {:ok, session} = Wallaby.start_session(metadata: metadata)
   ```

### JavaScript Errors

If you encounter JavaScript errors:

1. Check the browser logs:
   ```elixir
   # View browser logs
   IO.inspect(Wallaby.ChromeDriver.log(session.driver))
   ```

2. Use JavaScript execution:
   ```elixir
   # Execute JavaScript
   execute_script(session, "return document.querySelector('.element').textContent")
   |> IO.inspect(label: "Element text")
   ```

## Additional Resources

- [Wallaby Documentation](https://hexdocs.pm/wallaby/readme.html)
- [Wallaby GitHub Repository](https://github.com/elixir-wallaby/wallaby)
- [ChromeDriver Documentation](https://chromedriver.chromium.org/getting-started)
- [End-to-End Testing Best Practices](https://www.browserstack.com/guide/end-to-end-testing)