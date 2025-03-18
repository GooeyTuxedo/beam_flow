defmodule BeamFlow.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text
      add :excerpt, :text
      add :status, :string, null: false, default: "draft"
      add :published_at, :utc_datetime
      add :user_id, references(:users, on_delete: :nilify_all)
      # Will add featured_image_id when Media schema is implemented in Week 5

      timestamps()
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:status])
    create index(:posts, [:user_id])
    create index(:posts, [:published_at])
  end
end
