# Observability Standards for BeamFlow CMS

This guide outlines the standards and best practices for implementing observability in the BeamFlow CMS project. It covers structured logging, metrics collection, distributed tracing, and alerting.

## Overview

BeamFlow CMS uses a comprehensive observability stack:

1. **Structured Logging**: JSON-formatted logs with consistent context
2. **Metrics**: Prometheus metrics with Grafana dashboards
3. **Distributed Tracing**: OpenTelemetry for request tracing
4. **Alerting**: Grafana alerts based on metrics and logs

## Structured Logging

### Log Levels

Use appropriate log levels for different types of events:

- **`:debug`** - Detailed information useful during development
- **`:info`** - Normal application behavior, key business events
- **`:warn`** - Unexpected behavior that doesn't prevent operation
- **`:error`** - Errors that prevent specific operations
- **`:critical`** - Critical errors that may affect system stability

### Context and Metadata

Always include relevant context in log entries:

```elixir
# Base application metadata set in application.ex
Logger.metadata(app: "beam_flow")

# Add request-specific metadata in endpoint.ex or router.ex
Logger.metadata(
  request_id: conn.assigns[:request_id],
  user_id: conn.assigns[:current_user]?.id,
  remote_ip: to_string(:inet.ntoa(conn.remote_ip))
)

# Add context-specific metadata in business logic
Logger.metadata(post_id: post.id, action: "publish")
Logger.info("Post published successfully")
```

### Standard Log Structure

All log entries should follow a consistent structure:

```elixir
# In config/config.exs
config :logger, :console,
  format: {LoggerJSON.Formatter, :format},
  metadata: [
    :request_id,
    :user_id,
    :remote_ip,
    :module,
    :function,
    :file,
    :line,
    :application,
    :duration_ms
  ]

# Example log entry format:
# {
#   "timestamp": "2025-03-19T14:30:45.123Z",
#   "level": "info",
#   "message": "Post published successfully",
#   "request_id": "FzMIDJGBAAJtbm0AAAB8",
#   "user_id": "user_123",
#   "remote_ip": "192.168.1.1",
#   "module": "BeamFlow.Content",
#   "function": "publish_post/2",
#   "post_id": "post_456",
#   "action": "publish",
#   "duration_ms": 45
# }
```

### Logging Best Practices

1. **Be Selective**
   - Log important business events and state transitions
   - Avoid excessive logging of routine operations
   - Don't log sensitive information (passwords, tokens)

2. **Include Actionable Information**
   - Include IDs for related entities (user_id, post_id)
   - For errors, include relevant error details and context
   - Include timing information for performance-sensitive operations

```elixir
# Good error logging
def update_post(user, post_id, attrs) do
  start_time = System.monotonic_time()
  
  result =
    try do
      with {:ok, post} <- Content.get_post(post_id),
           :ok <- Accounts.authorize(user, post, :update),
           {:ok, updated} <- Content.update_post(post, attrs) do
        {:ok, updated}
      else
        {:error, :not_found} ->
          Logger.warn("Post not found", post_id: post_id, user_id: user.id)
          {:error, :not_found}
          
        {:error, :unauthorized} ->
          Logger.warn("Unauthorized post update attempt", 
            post_id: post_id, 
            user_id: user.id, 
            user_role: user.role
          )
          {:error, :unauthorized}
          
        {:error, %Ecto.Changeset{} = changeset} ->
          errors = format_changeset_errors(changeset)
          Logger.warn("Post update validation failed", 
            post_id: post_id, 
            user_id: user.id,
            validation_errors: errors
          )
          {:error, changeset}
      end
    rescue
      e ->
        Logger.error("Unexpected error updating post",
          post_id: post_id,
          user_id: user.id,
          error: inspect(e),
          stacktrace: __STACKTRACE__
        )
        reraise e, __STACKTRACE__
    end
    
  end_time = System.monotonic_time()
  duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
  
  Logger.metadata(duration_ms: duration_ms)
  
  if match?({:ok, _}, result) do
    Logger.info("Post updated successfully", post_id: post_id, user_id: user.id)
  end
  
  result
end

defp format_changeset_errors(changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end)
end
```

## Metrics Collection

BeamFlow CMS uses Prometheus for metrics collection and Grafana for visualization.

### Standard Metrics

Collect the following types of metrics:

1. **System Metrics**
   - VM stats (memory, CPU)
   - Process counts
   - GC stats

2. **HTTP Metrics**
   - Request counts by path and status
   - Response times
   - Error rates

3. **Database Metrics**
   - Query execution times
   - Connection pool utilization
   - Query counts by type

4. **Business Metrics**
   - User registrations and logins
   - Content creation and editing
   - Engagement metrics (comments, views)

### Metric Naming Conventions

Follow a consistent naming pattern for metrics:

- Use snake_case for metric names
- Use the format `namespace_subsystem_metric_unit`
- Include appropriate labels for filtering

Examples:
- `beam_flow_http_requests_total`
- `beam_flow_db_query_duration_milliseconds`
- `beam_flow_content_posts_created_total`

### Instrumenting Code

Use Telemetry for instrumenting code:

```elixir
# In application.ex
def start(_type, _args) do
  children = [
    # ... other children
    {TelemetryMetricsPrometheus, metrics: metrics()}
  ]
  
  opts = [strategy: :one_for_one, name: BeamFlow.Supervisor]
  Supervisor.start_link(children, opts)
end

defp metrics do
  [
    # HTTP metrics
    counter("beam_flow.http.requests.total",
      event_name: [:beam_flow, :http, :request, :stop],
      measurement: :count,
      tags: [:route, :status, :method]
    ),
    
    # Response time metrics
    distribution("beam_flow.http.request.duration.milliseconds",
      event_name: [:beam_flow, :http, :request, :stop],
      measurement: :duration,
      unit: {:native, :millisecond},
      tags: [:route, :status],
      reporter_options: [
        buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
      ]
    ),
    
    # Database metrics
    counter("beam_flow.repo.query.total",
      event_name: [:beam_flow, :repo, :query],
      measurement: :count,
      tags: [:source, :command]
    ),
    
    distribution("beam_flow.repo.query.duration.milliseconds",
      event_name: [:beam_flow, :repo, :query],
      measurement: :total_time,
      unit: {:native, :millisecond},
      tags: [:source, :command],
      reporter_options: [
        buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]
      ]
    ),
    
    # Business metrics
    counter("beam_flow.content.posts.created.total",
      event_name: [:beam_flow, :content, :post, :created],
      measurement: :count,
      tags: [:status, :author_role]
    ),
    
    counter("beam_flow.accounts.user.login.total",
      event_name: [:beam_flow, :accounts, :user, :login],
      measurement: :count,
      tags: [:success, :role]
    ),
    
    # VM metrics
    last_value("vm.memory.total",
      event_name: [:vm, :memory],
      measurement: :total,
      unit: :byte
    )
  ]
end

# Custom telemetry events
def handle_post_created(user, post) do
  :telemetry.execute(
    [:beam_flow, :content, :post, :created],
    %{count: 1},
    %{status: post.status, author_role: user.role}
  )
end
```

### Emitting Custom Events

Emit telemetry events for important business operations:

```elixir
# In your Content context
def create_post(user, attrs) do
  # ... post creation logic
  
  case result do
    {:ok, post} ->
      # Emit telemetry event
      :telemetry.execute(
        [:beam_flow, :content, :post, :created],
        %{count: 1},
        %{status: post.status, author_role: user.role}
      )
      
      {:ok, post}
      
    {:error, changeset} ->
      {:error, changeset}
  end
end
```

## Distributed Tracing

BeamFlow CMS uses OpenTelemetry for distributed tracing to track requests through the system.

### Trace Context

Ensure trace context is properly propagated:

- Between processes
- Across service boundaries
- Through PubSub messages

### Instrumenting Traces

1. **Automatic Instrumentation**
   - Phoenix controllers and endpoints
   - Ecto queries
   - HTTP client requests

```elixir
# In deps
def deps do
  [
    # ... other deps
    {:opentelemetry_api, "~> 1.0"},
    {:opentelemetry, "~> 1.0"},
    {:opentelemetry_exporter, "~> 1.0"},
    {:opentelemetry_phoenix, "~> 1.0"},
    {:opentelemetry_ecto, "~> 1.0"}
  ]
end

# In application.ex
def start(_type, _args) do
  :opentelemetry_phoenix.setup()
  :opentelemetry_ecto.setup([:beam_flow, :repo])
  
  # ... rest of start function
end
```

2. **Manual Instrumentation**
   - Add spans for important business operations
   - Add attributes for context

```elixir
def publish_post(user, post_id) do
  ctx = OpenTelemetry.Ctx.current()
  tracer = OpenTelemetry.Tracer.tracer()
  
  OpenTelemetry.Tracer.with_span ctx, tracer, "publish_post", %{
    attributes: %{
      "user.id" => user.id,
      "user.role" => user.role,
      "post.id" => post_id
    }
  } do
    # Get the current span context
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    
    # Add authorization check span
    OpenTelemetry.Tracer.with_span span_ctx, tracer, "authorize_user", %{} do
      case Accounts.authorize(user, :publish_post) do
        :ok -> :ok
        error -> 
          # Record error in span
          OpenTelemetry.Span.set_status(OpenTelemetry.status(:error, "Unauthorized"))
          OpenTelemetry.Span.add_event("authorization_failed", %{error: inspect(error)})
          error
      end
    end
    
    # Add post retrieval span
    {status, post} = OpenTelemetry.Tracer.with_span span_ctx, tracer, "get_post", %{} do
      case Content.get_post(post_id) do
        {:ok, post} -> {:ok, post}
        error -> 
          OpenTelemetry.Span.set_status(OpenTelemetry.status(:error, "Post not found"))
          {error, nil}
      end
    end
    
    case {status, post} do
      {{:ok, post}, _} ->
        # Add publish span
        OpenTelemetry.Tracer.with_span span_ctx, tracer, "update_post_status", %{} do
          case Content.update_post(post, %{status: "published"}) do
            {:ok, updated} -> {:ok, updated}
            error -> 
              OpenTelemetry.Span.set_status(OpenTelemetry.status(:error, "Update failed"))
              error
          end
        end
        
      {error, _} ->
        error
    end
  end
end
```

## Alerting

Set up alerts based on metrics and logs to proactively detect issues.

### Alert Thresholds

Define thresholds for key metrics:

1. **System Health**
   - High memory usage (> 80% for 5 minutes)
   - High CPU usage (> 90% for 5 minutes)
   - Low disk space (< 10% free)

2. **Application Health**
   - High error rate (> 1% errors for 5 minutes)
   - Slow response time (p95 > 1s for 5 minutes)
   - Database connection pool saturation (> 80% for 5 minutes)

3. **Business Health**
   - Dramatic drops in user activity
   - High rate of failed logins
   - Content creation failures

### Alert Configuration

Configure Grafana alerts:

```yaml
# Example Grafana alert rule (in provisioning/alerting/rules/api_errors.yaml)
apiVersion: 1
groups:
  - name: beam_flow_alerts
    folder: BeamFlow
    interval: 1m
    rules:
      - name: High Error Rate
        condition: B
        data:
          - refId: A
            datasourceUid: prometheus
            model:
              expr: sum(rate(beam_flow_http_requests_total{status=~"5.*"}[5m])) / sum(rate(beam_flow_http_requests_total[5m])) * 100 > 1
              instant: false
              intervalMs: 1000
              maxDataPoints: 43200
              refId: A
          - refId: B
            datasourceUid: __expr__
            model:
              conditions:
                - evaluator:
                    params: [0]
                    type: gt
                  operator:
                    type: and
                  query:
                    params: [A]
                  reducer:
                    type: avg
              datasource:
                type: __expr__
                uid: __expr__
              expression: A
              refId: B
              type: threshold
        noDataState: OK
        execErrState: Alerting
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: High error rate on API
          description: "More than 1% of requests are resulting in 5xx errors over the last 5 minutes."
```

## Dashboards

Create standard dashboards for monitoring:

1. **System Overview**
   - Node health
   - Memory and CPU usage
   - Disk space

2. **Application Performance**
   - Request rates and latencies
   - Error rates
   - Database performance

3. **Business Metrics**
   - User activity
   - Content creation
   - Engagement

### Dashboard Examples

```json
{
  "title": "BeamFlow API Performance",
  "uid": "beam_flow_api",
  "panels": [
    {
      "title": "Request Rate",
      "type": "timeseries",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(rate(beam_flow_http_requests_total[1m])) by (route)",
          "legendFormat": "{{route}}"
        }
      ]
    },
    {
      "title": "Error Rate",
      "type": "timeseries",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(rate(beam_flow_http_requests_total{status=~\"5.*\"}[1m])) / sum(rate(beam_flow_http_requests_total[1m])) * 100",
          "legendFormat": "Error %"
        }
      ]
    },
    {
      "title": "Response Time (p95)",
      "type": "timeseries",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(beam_flow_http_request_duration_milliseconds_bucket[5m])) by (le, route))",
          "legendFormat": "{{route}}"
        }
      ]
    }
  ]
}
```

## Integration with ELK Stack

Configure integration with Elasticsearch, Logstash, and Kibana for log aggregation and analysis.

### Logstash Configuration

```ruby
# config/logstash/beam_flow.conf
input {
  tcp {
    port => 5044
    codec => json
  }
}

filter {
  if [application] == "beam_flow" {
    # Add environment tag
    mutate {
      add_field => { "environment" => "${ENVIRONMENT:production}" }
    }
    
    # Parse timestamps
    date {
      match => [ "timestamp", "ISO8601" ]
      target => "@timestamp"
    }
    
    # Add log level tag
    if [level] in ["error", "critical"] {
      mutate {
        add_tag => [ "error" ]
      }
    }
    
    # Extract request path from route for easier querying
    if [route] {
      grok {
        match => { "route" => "%{WORD:http_method} %{URIPATHPARAM:request_path}" }
      }
    }
  }
}

output {
  if [application] == "beam_flow" {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "beam_flow-logs-%{+YYYY.MM.dd}"
      user => "${ELASTIC_USER:elastic}"
      password => "${ELASTIC_PASSWORD:changeme}"
    }
  }
}
```

## Best Practices

### 1. Design for Observability

- Emit logs and metrics at service boundaries
- Ensure all errors are properly logged with context
- Add tracing to complex operations

### 2. Correlate Data Sources

- Include request_id in logs and spans
- Use consistent naming across metrics, logs, and traces
- Ensure timestamps are synchronized

### 3. Balance Detail and Volume

- Be selective about what and when to log
- Use sampling for high-volume metrics and traces
- Configure appropriate retention periods

### 4. Secure Sensitive Data

- Never log sensitive information (passwords, tokens)
- Scrub PII from logs and traces
- Use appropriate access controls for dashboards

## Resources

- [Logger Documentation](https://hexdocs.pm/logger/Logger.html)
- [Telemetry Documentation](https://hexdocs.pm/telemetry/readme.html)
- [OpenTelemetry Documentation](https://hexdocs.pm/opentelemetry/OpenTelemetry.html)
- [ELK Stack Documentation](https://www.elastic.co/guide/index.html)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)