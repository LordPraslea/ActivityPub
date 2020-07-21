defmodule MoodleNet.Repo.Migrations.AddObjectsTable do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    ActivityPub.Migrations.change()

    # This table only exists for test purposes
    create table("local_actor", primary_key: false) do
      add :id, :uuid, primary_key: true
      add :username, :citext
      add :data, :map
      add :local, :boolean
      add :keys, :text
    end
  end
end