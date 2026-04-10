defmodule TodoApi.Todos.Repositories.MongoRepositoryTest do
  use ExUnit.Case, async: false

  alias TodoApi.Todos.Core
  alias TodoApi.Todos.Repositories.MongoRepository

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

  test "persists and fetches todos" do
    {:ok, todo} =
      Core.create(%{"title" => "integration todo", "priority" => "medium"}, DateTime.utc_now())

    assert {:ok, created} = MongoRepository.create(todo)
    assert {:ok, fetched} = MongoRepository.get(created.id)
    assert fetched.title == "integration todo"
  end
end
