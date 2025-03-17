defmodule BeamFlow.Repo do
  use Ecto.Repo,
    otp_app: :beam_flow,
    adapter: Ecto.Adapters.Postgres
end
