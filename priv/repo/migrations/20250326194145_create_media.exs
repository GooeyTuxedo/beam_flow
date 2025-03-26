defmodule BeamFlow.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create table(:media) do
      add :filename, :string, null: false
      add :original_filename, :string, null: false
      add :content_type, :string, null: false
      add :path, :string, null: false
      add :size, :integer, null: false
      add :alt_text, :string
      add :metadata, :map
      add :user_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:media, [:user_id])
    create index(:media, [:content_type])
    create unique_index(:media, [:path])
  end
end
