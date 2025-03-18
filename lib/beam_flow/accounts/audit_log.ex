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
    # Convert string keys to atoms throughout the metadata structure
    # to ensure consistent access patterns
    processed_attrs = process_metadata(attrs)

    audit_log
    |> cast(processed_attrs, [
      :action,
      :user_id,
      :ip_address,
      :metadata,
      :resource_id,
      :resource_type
    ])
    |> validate_required([:action])
  end

  # Process metadata to ensure consistent structure
  defp process_metadata(attrs) do
    metadata = attrs[:metadata] || attrs["metadata"] || %{}

    # Convert to map with string keys if it isn't already
    metadata =
      if is_map(metadata) do
        metadata
      else
        %{}
      end

    # Store metadata with string keys for Postgres compatibility
    # but preserve nested structure
    processed_metadata = deep_stringify_keys(metadata)

    # Update attrs
    case attrs do
      %{metadata: _data} -> %{attrs | metadata: processed_metadata}
      %{"metadata" => _data} -> %{attrs | "metadata" => processed_metadata}
      _rest -> Map.put(attrs, :metadata, processed_metadata)
    end
  end

  # Convert all keys in a nested map to strings
  defp deep_stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_map(v) -> {to_string(k), deep_stringify_keys(v)}
      {k, v} when is_list(v) -> {to_string(k), Enum.map(v, &stringify_list_item/1)}
      {k, v} -> {to_string(k), v}
    end)
    |> Enum.into(%{})
  end

  defp deep_stringify_keys(not_map), do: not_map

  defp stringify_list_item(item) when is_map(item), do: deep_stringify_keys(item)
  defp stringify_list_item(item), do: item

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
  def list_recent_logs(query \\ __MODULE__, limit \\ 50) when is_integer(limit) do
    from(l in query, order_by: [desc: l.inserted_at], limit: ^limit)
  end
end
