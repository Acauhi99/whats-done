defmodule TodoApi.Todos.Repositories.InMemoryRepository do
  @moduledoc false

  @behaviour TodoApi.Todos.Repository

  alias TodoApi.Todos.Todo

  @table :todo_api_test_todos

  @impl true
  def list(filters) do
    ensure_table()

    items =
      @table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, todo} -> todo end)
      |> Enum.filter(&matches_filters?(&1, filters))
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    total = length(items)
    page = filters.page
    page_size = filters.page_size

    page_items =
      items
      |> Enum.drop((page - 1) * page_size)
      |> Enum.take(page_size)

    {:ok, %{items: page_items, total: total, page: page, page_size: page_size}}
  end

  @impl true
  def get(id) when is_binary(id) do
    ensure_table()

    case :ets.lookup(@table, id) do
      [{^id, todo}] -> {:ok, todo}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def create(%Todo{} = todo) do
    ensure_table()

    id = Integer.to_string(System.unique_integer([:positive]))
    created = %Todo{todo | id: id}
    true = :ets.insert(@table, {id, created})
    {:ok, created}
  end

  @impl true
  def update(%Todo{id: id} = todo) when is_binary(id) do
    ensure_table()

    case :ets.lookup(@table, id) do
      [] ->
        {:error, :not_found}

      _ ->
        true = :ets.insert(@table, {id, todo})
        {:ok, todo}
    end
  end

  def update(%Todo{id: nil}), do: {:error, :invalid_id}

  @impl true
  def delete(id) when is_binary(id) do
    ensure_table()

    case :ets.lookup(@table, id) do
      [] ->
        {:error, :not_found}

      _ ->
        true = :ets.delete(@table, id)
        :ok
    end
  end

  def clear do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])
        :ok

      _tid ->
        :ok
    end
  end

  defp matches_filters?(todo, filters) do
    matches_done?(todo, filters.done) and
      matches_priority?(todo, filters.priority) and
      matches_q?(todo, filters.q) and
      matches_tags?(todo, filters.tags)
  end

  defp matches_done?(_todo, nil), do: true
  defp matches_done?(todo, done), do: todo.done == done

  defp matches_priority?(_todo, nil), do: true
  defp matches_priority?(todo, priority), do: todo.priority == priority

  defp matches_q?(_todo, nil), do: true

  defp matches_q?(todo, q) do
    downcased = String.downcase(q)

    title_match = String.contains?(String.downcase(todo.title), downcased)

    description_match =
      case todo.description do
        nil -> false
        description -> String.contains?(String.downcase(description), downcased)
      end

    title_match or description_match
  end

  defp matches_tags?(_todo, []), do: true
  defp matches_tags?(todo, tags), do: Enum.all?(tags, &(&1 in todo.tags))
end
