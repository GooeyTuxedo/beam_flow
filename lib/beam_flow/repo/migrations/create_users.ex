defmodule BeamFlow.Repo.Migrations.CreateUsers do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string, null: false
      add :bio, :text
      add :password_hash, :string, null: false
      add :confirmed_at, :naive_datetime
      add :role, :string, null: false, default: "subscriber"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    # Create users_tokens table for session management and password resets
    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    # Create audit_logs table for tracking sensitive operations
    create table(:audit_logs) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :ip_address, :string
      add :metadata, :map
      add :resource_id, :string
      add :resource_type, :string

      timestamps(updated_at: false)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:resource_type, :resource_id])
  end
end
