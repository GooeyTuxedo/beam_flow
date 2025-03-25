defmodule BeamFlow.Repo.Migrations.CreatePostCategories do
  use Ecto.Migration

  def change do
    create table(:post_categories, primary_key: false) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false
    end

    create unique_index(:post_categories, [:post_id, :category_id])
    create index(:post_categories, [:category_id])
  end
end
