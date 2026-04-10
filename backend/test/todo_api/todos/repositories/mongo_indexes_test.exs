defmodule TodoApi.Todos.Repositories.MongoIndexesTest do
  use ExUnit.Case, async: false

  alias TodoApi.Todos.Repositories.MongoIndexes

  @moduletag :integration

  setup_all do
    mongo_url = System.get_env("MONGO_URL", "mongodb://localhost:27017/todo_api_test")

    case Mongo.start_link(name: TodoApi.Mongo, url: mongo_url) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok = Mongo.drop_collection(TodoApi.Mongo, "todos")

    on_exit(fn ->
      _ = Mongo.drop_collection(TodoApi.Mongo, "todos")
    end)

    :ok
  end

  test "creates expected indexes for todos collection" do
    assert :ok = MongoIndexes.ensure_indexes()

    cursor = Mongo.list_indexes(TodoApi.Mongo, "todos")
    index_names = cursor |> Enum.map(&Map.get(&1, "name")) |> Enum.sort()

    assert "inserted_at_desc_idx" in index_names
    assert "done_priority_inserted_at_idx" in index_names
    assert "tags_idx" in index_names
  end
end
