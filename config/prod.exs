import Config

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :beam_flow, BeamFlowWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :beam_flow, :async_logging, true

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: BeamFlow.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger,
  level: :info,
  backends: [LoggerJSON]

config :logger_json, :backend,
  metadata: [:request_id, :user_id, :role, :ip, :method, :path, :status, :duration],
  json_encoder: Jason,
  formatter: LoggerJSON.Formatters.Basic,
  on_init: {BeamFlow.LoggerJSON.Config, :setup, []}

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {
      :opentelemetry_exporter,
      %{
        endpoint: "http://otel-collector:4318/v1/traces",
        protocol: :http_protobuf
      }
    }
  }

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
