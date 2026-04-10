defmodule TodoApi.Todos.Caches.ValkeyCache do
  @moduledoc false

  @behaviour TodoApi.Todos.Cache

  alias TodoApi.Todos.Todo

  @prefix "todos:list:"
  @scan_count "100"

  @impl true
  def get_list(filters) do
    case Redix.command(TodoApi.Valkey, ["GET", cache_key(filters)]) do
      {:ok, nil} ->
        :miss

      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, value} -> {:hit, normalize_page(value)}
          _ -> :miss
        end

      _ ->
        :miss
    end
  end

  @impl true
  def put_list(filters, value) do
    ttl =
      Application.fetch_env!(:todo_api, :todos)
      |> Keyword.get(:cache_ttl_seconds, 120)

    command = [
      "SETEX",
      cache_key(filters),
      Integer.to_string(ttl),
      Jason.encode!(serialize_page(value))
    ]

    case Redix.command(TodoApi.Valkey, command) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  @impl true
  def invalidate_lists do
    scan_and_delete("0")
  end

  defp cache_key(filters) do
    serialized = Jason.encode!(filters)
    @prefix <> Integer.to_string(:erlang.phash2(serialized))
  end

  defp serialize_page(%{items: items, page: page, page_size: page_size, total: total}) do
    %{
      "items" => Enum.map(items, &serialize_item/1),
      "page" => page,
      "page_size" => page_size,
      "total" => total
    }
  end

  defp serialize_item(%Todo{} = todo) do
    %{
      "id" => todo.id,
      "title" => todo.title,
      "description" => todo.description,
      "done" => todo.done,
      "due_date" => serialize_datetime(todo.due_date),
      "priority" => Atom.to_string(todo.priority),
      "tags" => todo.tags,
      "inserted_at" => serialize_datetime(todo.inserted_at),
      "updated_at" => serialize_datetime(todo.updated_at)
    }
  end

  defp serialize_item(item) when is_map(item), do: item

  defp normalize_page(%{
         "items" => items,
         "page" => page,
         "page_size" => page_size,
         "total" => total
       }) do
    %{
      items: Enum.map(items, &normalize_item/1),
      page: page,
      page_size: page_size,
      total: total
    }
  end

  defp normalize_page(_), do: %{items: [], page: 1, page_size: 20, total: 0}

  defp normalize_item(item) when is_map(item), do: item

  defp serialize_datetime(nil), do: nil
  defp serialize_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp scan_and_delete(cursor) do
    case Redix.command(TodoApi.Valkey, [
           "SCAN",
           cursor,
           "MATCH",
           "#{@prefix}*",
           "COUNT",
           @scan_count
         ]) do
      {:ok, [next_cursor, keys]} when is_list(keys) ->
        :ok = delete_keys(keys)

        if next_cursor == "0" do
          :ok
        else
          scan_and_delete(next_cursor)
        end

      _ ->
        :ok
    end
  end

  defp delete_keys([]), do: :ok

  defp delete_keys(keys) do
    _ = Redix.command(TodoApi.Valkey, ["DEL" | keys])
    :ok
  end
end
