defmodule BeamFlow.Repo.Migrations.AddFeaturedImageToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :featured_image_id, references(:media, on_delete: :nilify_all)
    end

    create index(:posts, [:featured_image_id])
  end
end
