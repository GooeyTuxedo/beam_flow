# Security Best Practices for BeamFlow CMS

This document outlines security best practices for the BeamFlow CMS project. Following these guidelines helps prevent common security vulnerabilities and protect user data.

## Authentication

### Password Storage

- **Never** store plain-text passwords
- Use Argon2 for password hashing
- Configure appropriate hash parameters for security and performance

```elixir
# In mix.exs
defp deps do
  [
    # ... other deps
    {:argon2_elixir, "~> 3.0"}
  ]
end

# In User schema/module
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :password])
  |> validate_required([:email, :password])
  |> validate_length(:password, min: 10)
  |> validate_password_strength()
  |> put_password_hash()
end

defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
  put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
end
defp put_password_hash(changeset), do: changeset

defp validate_password_strength(changeset) do
  password = get_change(changeset, :password)
  
  if password && !strong_password?(password) do
    add_error(
      changeset, 
      :password, 
      "must include uppercase and lowercase letters, at least one number, and at least one special character"
    )
  else
    changeset
  end
end

defp strong_password?(password) do
  # At least 10 characters
  # At least one uppercase letter
  # At least one lowercase letter
  # At least one number
  # At least one special character
  String.length(password) >= 10 &&
    String.match?(password, ~r/[A-Z]/) &&
    String.match?(password, ~r/[a-z]/) &&
    String.match?(password, ~r/[0-9]/) &&
    String.match?(password, ~r/[^A-Za-z0-9]/)
end
```

### Session Management

- Use `Phoenix.Token` for stateless authentication
- Set appropriate token expiration
- Implement token refreshing
- Store session IDs securely

```elixir
# In accounts.ex
def generate_user_token(user) do
  Phoenix.Token.sign(
    BeamFlowWeb.Endpoint,
    "user auth",
    user.id,
    max_age: 86400 * 30  # 30 days
  )
end

def verify_user_token(token) do
  Phoenix.Token.verify(
    BeamFlowWeb.Endpoint,
    "user auth",
    token,
    max_age: 86400 * 30  # 30 days
  )
end
```

### Multi-Factor Authentication

Implement multi-factor authentication for secure accounts:

```elixir
# In schema/account.ex
schema "accounts" do
  # ... other fields
  field :otp_secret, :string
  field :otp_enabled, :boolean, default: false
end

# In accounts.ex
def enable_totp(user) do
  secret = NimbleTOTP.secret()
  
  user
  |> Ecto.Changeset.change(%{
    otp_secret: Base.encode32(secret),
    otp_enabled: true
  })
  |> Repo.update()
end

def verify_totp(user, code) do
  if user.otp_enabled do
    secret = Base.decode32!(user.otp_secret)
    NimbleTOTP.valid?(secret, code)
  else
    false
  end
end
```

## Authorization

### Role-Based Access Control

- Define clear roles (admin, editor, author, etc.)
- Implement permission checks consistently
- Check permissions at both controller and context levels

```elixir
# In accounts.ex
def authorize(user, resource, action) do
  case {user.role, resource, action} do
    # Admin can do everything
    {"admin", _, _} -> :ok
    
    # Editor can publish any post
    {"editor", %Post{}, :publish} -> :ok
    
    # Author can edit own posts
    {"author", %Post{user_id: user_id}, :edit} when user_id == user.id -> :ok
    
    # Author can create posts
    {"author", Post, :create} -> :ok
    
    # Deny by default
    _ -> {:error, :unauthorized}
  end
end

# In context modules
def update_post(user, post, attrs) do
  with :ok <- Accounts.authorize(user, post, :update) do
    # Update logic
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end
end

# In controllers/LiveView
def update(conn, %{"id" => id, "post" => post_params}) do
  post = Content.get_post!(id)
  user = conn.assigns.current_user
  
  case Content.update_post(user, post, post_params) do
    {:ok, post} ->
      redirect(to: ~p"/posts/#{post}")
      
    {:error, :unauthorized} ->
      conn
      |> put_flash(:error, "You are not authorized to update this post")
      |> redirect(to: ~p"/posts")
      
    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, :edit, post: post, changeset: changeset)
  end
end
```

### Policy Objects

For complex authorization logic, use policy objects:

```elixir
# In lib/beam_flow/policies/post_policy.ex
defmodule BeamFlow.Policies.PostPolicy do
  alias BeamFlow.Accounts.User
  alias BeamFlow.Content.Post
  
  def can?(user, action, resource)
  
  # Admin can do anything
  def can?(%User{role: "admin"}, _action, _resource), do: true
  
  # Editors can publish posts
  def can?(%User{role: "editor"}, :publish, %Post{}), do: true
  
  # Authors can edit their own posts
  def can?(%User{id: user_id, role: "author"}, :update, %Post{user_id: post_user_id})
      when user_id == post_user_id, do: true
      
  # Authors can create posts
  def can?(%User{role: "author"}, :create, Post), do: true
  
  # Public can view published posts
  def can?(_user, :view, %Post{status: "published"}), do: true
  
  # Default deny
  def can?(_user, _action, _resource), do: false
end
```

## Input Validation

### Form Data Validation

- Validate all user input
- Use Phoenix changesets for structured validation
- Sanitize data before storage or rendering

```elixir
# In schema
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :content, :status])
  |> validate_required([:title, :content])
  |> validate_length(:title, max: 255)
  |> validate_length(:content, max: 50_000)
  |> validate_inclusion(:status, ["draft", "published", "scheduled"])
  |> sanitize_content()
end

# Sanitize HTML content
defp sanitize_content(%Ecto.Changeset{valid?: true, changes: %{content: content}} = changeset) when is_binary(content) do
  sanitized = HtmlSanitizeEx.basic_html(content)
  put_change(changeset, :content, sanitized)
end
defp sanitize_content(changeset), do: changeset
```

### File Upload Security

- Validate file types
- Set maximum file sizes
- Scan for malware if possible
- Store files securely with proper permissions

```elixir
def upload_changeset(upload, attrs) do
  upload
  |> cast(attrs, [:file])
  |> validate_required([:file])
  |> validate_file_type()
  |> validate_file_size()
end

defp validate_file_type(changeset) do
  case get_change(changeset, :file) do
    %Plug.Upload{content_type: content_type} ->
      if content_type in allowed_content_types() do
        changeset
      else
        add_error(changeset, :file, "has an invalid file type")
      end
    _ -> changeset
  end
end

defp validate_file_size(changeset) do
  case get_change(changeset, :file) do
    %Plug.Upload{path: path} ->
      case File.stat(path) do
        {:ok, %{size: size}} when size > 10_000_000 ->
          add_error(changeset, :file, "is too large (max 10MB)")
        _ -> changeset
      end
    _ -> changeset
  end
end

defp allowed_content_types do
  [
    "image/jpeg",
    "image/png",
    "image/gif",
    "application/pdf"
  ]
end
```

## Cross-Site Scripting (XSS) Prevention

### Output Encoding

- Always use Phoenix's HTML helpers for rendering user content
- Escape all user-generated content properly

```elixir
# In template (safe)
<h1><%= @post.title %></h1>
<div><%= @post.content %></div>

# In LiveView (safe)
<h1><%= @post.title %></h1>
<div><%= raw(@post.content) |> HtmlSanitizeEx.basic_html() %></div>

# Avoiding common mistakes:
# DON'T do this (unsafe):
<div><%= raw(@post.content) %></div>
```

### Content Security Policy

Set up a proper Content Security Policy:

```elixir
# In endpoint.ex
plug :put_secure_browser_headers, %{
  "content-security-policy" => "default-src 'self'; " <>
                               "script-src 'self' https://cdnjs.cloudflare.com; " <>
                               "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " <>
                               "font-src 'self' https://fonts.gstatic.com; " <>
                               "img-src 'self' data:; " <>
                               "connect-src 'self' wss://"
}
```

## Cross-Site Request Forgery (CSRF) Protection

- Enable CSRF protection in all forms
- Include CSRF tokens in AJAX requests

```elixir
# In router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {BeamFlowWeb.Layouts, :root}
  plug :protect_from_forgery  # CSRF protection
  plug :put_secure_browser_headers
end

# In form (with csrf token)
<.form let={f} for={@changeset} action={@action} multipart={true}>
  <!-- Form inputs here -->
  <div class="mt-4">
    <%= submit "Save", class: "btn btn-primary" %>
  </div>
</.form>

# In JavaScript (for AJAX)
function sendRequest(url, method, data) {
  const token = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  
  return fetch(url, {
    method: method,
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": token
    },
    body: JSON.stringify(data)
  });
}
```

## SQL Injection Prevention

- Use Ecto for database queries
- Avoid raw SQL queries
- If raw SQL is necessary, use parameterized queries

```elixir
# Good - Ecto query
def get_posts_by_status(status) do
  Post
  |> where([p], p.status == ^status)
  |> Repo.all()
end

# Good - If raw SQL is needed, use parameters
def search_posts_raw(term) do
  query = "SELECT * FROM posts WHERE title ILIKE $1 OR content ILIKE $1"
  Ecto.Adapters.SQL.query!(Repo, query, ["%#{term}%"])
end

# Bad - Don't do this!
def dangerous_search(term) do
  query = "SELECT * FROM posts WHERE title LIKE '%#{term}%'"
  Ecto.Adapters.SQL.query!(Repo, query, [])
end
```

## API Security

### API Authentication

- Use JWT or Phoenix.Token for API authentication
- Implement proper expiration and refresh
- Consider OAuth2 for third-party integrations

```elixir
# In accounts.ex
def generate_api_token(user) do
  Phoenix.Token.sign(
    BeamFlowWeb.Endpoint,
    "api auth",
    user.id,
    max_age: 86400  # 24 hours
  )
end

def verify_api_token(token) do
  case Phoenix.Token.verify(
    BeamFlowWeb.Endpoint,
    "api auth",
    token,
    max_age: 86400
  ) do
    {:ok, user_id} -> 
      {:ok, Accounts.get_user!(user_id)}
    {:error, reason} -> 
      {:error, reason}
  end
end

# In API controller
defmodule BeamFlowWeb.Api.PostController do
  use BeamFlowWeb, :controller
  
  plug :verify_token when action not in [:index, :show]
  
  def verify_token(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.verify_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ -> 
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or missing authentication token"})
        |> halt()
    end
  end
  
  # Controller actions...
end
```

### Rate Limiting

Implement rate limiting for API endpoints:

```elixir
# In deps
defp deps do
  [
    # ... other deps
    {:ex_rated, "~> 2.0"}
  ]
end

# In API controller
defmodule BeamFlowWeb.Api.PostController do
  use BeamFlowWeb, :controller
  
  plug :rate_limit when action in [:create, :update, :delete]
  
  def rate_limit(conn, _opts) do
    ip = to_string(:inet.ntoa(conn.remote_ip))
    key = "api:#{ip}"
    
    case ExRated.check_rate(key, 60_000, 30) do  # 30 requests per minute
      {:ok, _} -> conn
      {:error, _} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "Rate limit exceeded. Please try again later."})
        |> halt()
    end
  end
  
  # Controller actions...
end
```

## Secure Configuration Management

### Environment Variables

- Use environment variables for sensitive configuration
- Never commit sensitive data to version control
- Use a .env file for local development (add to .gitignore)

```elixir
# In config/runtime.exs
config :beam_flow, BeamFlow.Repo,
  username: System.get_env("DATABASE_USERNAME"),
  password: System.get_env("DATABASE_PASSWORD"),
  hostname: System.get_env("DATABASE_HOST"),
  database: System.get_env("DATABASE_NAME"),
  stacktrace: false,
  show_sensitive_data_on_connection_error: false,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :beam_flow, BeamFlowWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """
```

### Secrets Management

- Use a secure vault for production secrets (e.g., HashiCorp Vault)
- Rotate secrets regularly
- Implement a secrets rotation process

## Audit Logging

Implement audit logging for security events:

```elixir
defmodule BeamFlow.AuditLog do
  alias BeamFlow.Repo
  alias BeamFlow.AuditLog.Entry
  
  def log_event(user, action, resource, metadata \\ %{}) do
    %Entry{}
    |> Entry.changeset(%{
      user_id: user.id,
      action: action,
      resource_type: resource_type(resource),
      resource_id: resource_id(resource),
      metadata: metadata,
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent]
    })
    |> Repo.insert()
  end
  
  defp resource_type(%{__struct__: struct}), do: struct |> to_string() |> String.split(".") |> List.last()
  defp resource_type(resource) when is_atom(resource), do: resource |> to_string()
  defp resource_type(_), do: "unknown"
  
  defp resource_id(%{id: id}), do: to_string(id)
  defp resource_id(_), do: nil
end

# In accounts.ex
def login_user(email, password, metadata \\ %{}) do
  user = get_user_by_email(email)
  
  with %User{} = user <- user,
       true <- verify_password(user, password) do
    
    # Log successful login
    AuditLog.log_event(user, "login", User, metadata)
    {:ok, user}
  else
    _ ->
      # Log failed login attempt
      if user do
        AuditLog.log_event(user, "failed_login", User, metadata)
      else
        AuditLog.log_event(%{id: nil}, "failed_login", %{email: email}, metadata)
      end
      
      {:error, :invalid_credentials}
  end
end
```

## Transport Layer Security

### HTTPS Configuration

- Enable HTTPS for all traffic
- Configure proper SSL/TLS settings
- Use HTTP Strict Transport Security (HSTS)

```elixir
# In config/runtime.exs
config :beam_flow, BeamFlowWeb.Endpoint,
  force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]],
  https: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH"),
    transport_options: [socket_opts: [:inet6]]
  ]
```

### Secure Cookie Handling

- Set secure and HttpOnly flags on cookies
- Use SameSite attribute appropriately

```elixir
# In endpoint.ex
plug Plug.Session,
  store: :cookie,
  key: "_beam_flow_key",
  signing_salt: "someSigningSalt",
  extra: "SameSite=Strict",
  encryption_salt: "someEncryptionSalt",
  key_iterations: 1000,
  key_length: 32,
  key_digest: :sha256,
  serializer: Poison,
  log: :debug,
  secure: true,
  http_only: true
```

## Dependency Management

### Package Security

- Regularly update dependencies
- Monitor for vulnerabilities in dependencies
- Use tools like `mix hex.audit` and GitHub security alerts

```bash
# Check dependencies for security vulnerabilities
mix hex.audit

# Keep dependencies up to date
mix hex.outdated
```

### Supply Chain Security

- Pin dependency versions for production builds
- Verify package integrity with checksums
- Consider a private package repository for sensitive code

## Secure Development Practices

### Security Code Reviews

- Implement mandatory security reviews for sensitive code
- Use a checklist for security-related changes
- Train developers on secure coding practices

### Security Testing

- Include security tests in CI/CD pipeline
- Perform regular penetration testing
- Use static analysis tools for security issues

```elixir
# In deps for development testing
defp deps do
  [
    # ... other deps
    {:sobelow, "~> 0.12", only: [:dev, :test], runtime: false}
  ]
end

# Add custom mix task for security scan
defmodule Mix.Tasks.Security.Scan do
  use Mix.Task

  @shortdoc "Run security scan on the codebase"
  def run(_) do
    Mix.shell().info("Running security scans...")
    Mix.shell().cmd("mix sobelow --config")
    # Add other security scan commands here
  end
end
```

## Incident Response

### Security Logging

- Log security events with appropriate detail
- Ensure logs are stored securely
- Implement log rotation and retention policies

### Breach Response Plan

1. **Preparation**
   - Document security contacts
   - Define roles and responsibilities
   - Create communication templates

2. **Detection**
   - Monitor security logs
   - Set up alerts for suspicious activities
   - Enable user reporting of security issues

3. **Containment**
   - Isolate affected systems
   - Revoke compromised credentials
   - Block malicious IP addresses

4. **Eradication**
   - Remove malicious code or accounts
   - Fix security vulnerabilities
   - Reset affected systems

5. **Recovery**
   - Restore systems from clean backups
   - Reset passwords
   - Monitor for repeat attacks

6. **Lessons Learned**
   - Document the incident
   - Update security measures
   - Train team members

## Compliance Considerations

### GDPR Compliance

- Implement data subject rights (access, portability, erasure)
- Document data processing activities
- Ensure proper consent management

```elixir
# Example of a data export function for GDPR compliance
def export_user_data(user_id) do
  user = Accounts.get_user!(user_id)
  
  # Collect all user-related data
  posts = Content.list_posts_by_user(user)
  comments = Engagement.list_comments_by_user(user)
  activities = Engagement.list_activities_by_user(user)
  
  # Format for export
  %{
    user: %{
      email: user.email,
      name: user.name,
      registered_at: user.inserted_at
    },
    posts: Enum.map(posts, fn post -> 
      %{
        title: post.title,
        content: post.content,
        created_at: post.inserted_at
      }
    end),
    comments: Enum.map(comments, fn comment -> 
      %{
        content: comment.content,
        created_at: comment.inserted_at
      }
    end),
    activities: Enum.map(activities, fn activity -> 
      %{
        action: activity.action,
        performed_at: activity.inserted_at
      }
    end)
  }
  |> Jason.encode!(pretty: true)
end

# Example of data deletion function
def delete_user_data(user_id) do
  user = Accounts.get_user!(user_id)
  
  Ecto.Multi.new()
  |> Ecto.Multi.delete_all(:delete_activities, Engagement.Activity.by_user(user))
  |> Ecto.Multi.delete_all(:delete_comments, Engagement.Comment.by_user(user))
  |> Ecto.Multi.update_all(:anonymize_posts, Content.Post.by_user(user), set: [
    content: "[Content removed]",
    user_id: nil,
    anonymous_author: user.name
  ])
  |> Ecto.Multi.delete(:delete_user, user)
  |> Repo.transaction()
end
```

### Security Compliance Checklists

Implement checklists for common security standards:

- OWASP Top 10
- CWE Top 25
- SOC 2 controls
- ISO 27001 requirements

## Resources

- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Phoenix Security Documentation](https://hexdocs.pm/phoenix/security.html)
- [Elixir Security Handbook](https://github.com/ninoseki/elixir-security-handbook)
- [BeamFlow CMS Testing Overview](../testing/overview.md)