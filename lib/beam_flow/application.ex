defmodule BeamFlow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok = setup_opentelemetry()

    children = [
      BeamFlowWeb.Telemetry,
      BeamFlow.Repo,
      {DNSCluster, query: Application.get_env(:beam_flow, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BeamFlow.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BeamFlow.Finch},
      # Start a worker by calling: BeamFlow.Worker.start_link(arg)
      # {BeamFlow.Worker, arg},
      # Start the rate limiter for login attempts
      {BeamFlow.Accounts.RateLimiter, []},
      # Start to serve requests, typically the last entry
      BeamFlowWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BeamFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BeamFlowWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp setup_opentelemetry do
    # Set up automatic instrumentation for Phoenix and Ecto
    :ok = OpentelemetryPhoenix.setup([])
    :ok = OpentelemetryEcto.setup([:beam_flow, :repo])
    :ok
  end
end
