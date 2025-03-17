defmodule BeamFlow.Accounts.AuditLog do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "audit_logs" do
    field :action, :string
    field :ip_address, :string
    field :metadata, :map, default: %{}
    field :resource_id, :string
    field :resource_type, :string

    belongs_to :user, BeamFlow.Accounts.User

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for an audit log entry.
  """
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:action, :user_id, :ip_address, :metadata, :resource_id, :resource_type])
    |> validate_required([:action])
  end

  @doc """
  Logs an action performed by a user.
  """
  def log_action(repo, action, user_id, opts \\ []) do
    %__MODULE__{}
    |> changeset(%{
      action: action,
      user_id: user_id,
      ip_address: opts[:ip_address],
      metadata: opts[:metadata] || %{},
      resource_id: opts[:resource_id],
      resource_type: opts[:resource_type]
    })
    |> repo.insert()
  end

  @doc """
  Returns the list of audit logs for a specific user.
  """
  def list_user_logs(query \\ __MODULE__, user_id) do
    from(l in query, where: l.user_id == ^user_id, order_by: [desc: l.inserted_at])
  end

  @doc """
  Returns the list of audit logs for a specific resource.
  """
  def list_resource_logs(query \\ __MODULE__, resource_type, resource_id) do
    from(l in query,
      where: l.resource_type == ^resource_type and l.resource_id == ^resource_id,
      order_by: [desc: l.inserted_at]
    )
  end

  @doc """
  Returns the list of recent audit logs.
  """
  def list_recent_logs(query \\ __MODULE__, limit \\ 50) do
    from(l in query, order_by: [desc: l.inserted_at], limit: ^limit)
  end
end
