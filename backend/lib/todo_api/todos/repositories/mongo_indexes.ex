defmodule TodoApi.Todos.Repositories.MongoIndexes do
  @moduledoc false

  require Logger

  @collection "todos"

  @indexes [
    [key: [inserted_at: -1], name: "inserted_at_desc_idx"],
    [key: [done: 1, priority: 1, inserted_at: -1], name: "done_priority_inserted_at_idx"],
    [key: [tags: 1], name: "tags_idx"]
  ]

  @spec ensure_indexes() :: :ok
  def ensure_indexes do
    case Mongo.create_indexes(TodoApi.Mongo, @collection, @indexes) do
      :ok ->
        :ok

      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("failed to ensure mongo indexes: #{inspect(reason)}")
        :ok
    end
  rescue
    error ->
      Logger.warning("failed to ensure mongo indexes: #{inspect(error)}")
      :ok
  end
end
