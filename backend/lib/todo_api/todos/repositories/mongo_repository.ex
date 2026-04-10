defmodule TodoApi.Todos.Repositories.MongoRepository do
  @moduledoc false

  @behaviour TodoApi.Todos.Repository

  alias TodoApi.Todos.Todo

  @collection "todos"

  @impl true
  def list(filters) do
    mongo_filter = build_filter(filters)

    opts = [
      skip: (filters.page - 1) * filters.page_size,
      limit: filters.page_size,
      sort: %{"inserted_at" => -1}
    ]

    with {:ok, cursor} <- find(mongo_filter, opts),
         {:ok, total} <- count(mongo_filter) do
      items = Enum.map(cursor, &from_document/1)
      {:ok, %{items: items, total: total, page: filters.page, page_size: filters.page_size}}
    end
  end

  @impl true
  def get(id) when is_binary(id) do
    with {:ok, object_id} <- decode_id(id),
         {:ok, maybe_doc} <- find_one(%{_id: object_id}),
         {:ok, todo} <- from_maybe_document(maybe_doc) do
      {:ok, todo}
    end
  end

  @impl true
  def create(%Todo{} = todo) do
    document = to_document(todo)

    case Mongo.insert_one(TodoApi.Mongo, @collection, document) do
      {:ok, result} ->
        inserted_id = Map.get(result, :inserted_id)
        {:ok, %Todo{todo | id: encode_id(inserted_id)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def update(%Todo{id: id} = todo) when is_binary(id) do
    with {:ok, object_id} <- decode_id(id),
         {:ok, result} <-
           Mongo.replace_one(
             TodoApi.Mongo,
             @collection,
             %{_id: object_id},
             to_document(todo)
           ),
         :ok <- ensure_matched(result) do
      {:ok, todo}
    end
  end

  def update(%Todo{id: nil}), do: {:error, :invalid_id}

  @impl true
  def delete(id) when is_binary(id) do
    with {:ok, object_id} <- decode_id(id),
         {:ok, result} <- Mongo.delete_one(TodoApi.Mongo, @collection, %{_id: object_id}),
         :ok <- ensure_deleted(result) do
      :ok
    end
  end

  defp find(filter, opts) do
    {:ok, Mongo.find(TodoApi.Mongo, @collection, filter, opts)}
  rescue
    error -> {:error, error}
  end

  defp find_one(filter) do
    {:ok, Mongo.find_one(TodoApi.Mongo, @collection, filter)}
  rescue
    error -> {:error, error}
  end

  defp count(filter) do
    case Mongo.count_documents(TodoApi.Mongo, @collection, filter) do
      {:ok, total} when is_integer(total) -> {:ok, total}
      total when is_integer(total) -> {:ok, total}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp from_maybe_document(nil), do: {:error, :not_found}
  defp from_maybe_document(document), do: {:ok, from_document(document)}

  defp from_document(document) do
    %Todo{
      id: encode_id(Map.get(document, "_id") || Map.get(document, :_id)),
      title: read_string(document, "title"),
      description: read_optional_string(document, "description"),
      done: read_boolean(document, "done", false),
      due_date: read_datetime(document, "due_date"),
      priority: read_priority(document, "priority"),
      tags: read_tags(document, "tags"),
      inserted_at: read_datetime(document, "inserted_at") || DateTime.utc_now(),
      updated_at: read_datetime(document, "updated_at") || DateTime.utc_now()
    }
  end

  defp to_document(todo) do
    %{
      "title" => todo.title,
      "description" => todo.description,
      "done" => todo.done,
      "due_date" => maybe_datetime_to_iso8601(todo.due_date),
      "priority" => Atom.to_string(todo.priority),
      "tags" => todo.tags,
      "inserted_at" => maybe_datetime_to_iso8601(todo.inserted_at),
      "updated_at" => maybe_datetime_to_iso8601(todo.updated_at)
    }
    |> maybe_put_id(todo.id)
  end

  defp maybe_put_id(document, nil), do: document

  defp maybe_put_id(document, id) do
    case decode_id(id) do
      {:ok, object_id} -> Map.put(document, "_id", object_id)
      _ -> document
    end
  end

  defp ensure_matched(result) do
    if matched_count(result) > 0, do: :ok, else: {:error, :not_found}
  end

  defp ensure_deleted(result) do
    if deleted_count(result) > 0, do: :ok, else: {:error, :not_found}
  end

  defp matched_count(result) do
    Map.get(result, :matched_count, Map.get(result, "matched_count", 0))
  end

  defp deleted_count(result) do
    Map.get(result, :deleted_count, Map.get(result, "deleted_count", 0))
  end

  defp decode_id(id) when is_binary(id) do
    try do
      {:ok, BSON.ObjectId.decode!(id)}
    rescue
      _ -> {:error, :invalid_id}
    end
  end

  defp encode_id(%BSON.ObjectId{} = object_id), do: BSON.ObjectId.encode!(object_id)
  defp encode_id(value) when is_binary(value), do: value
  defp encode_id(_), do: nil

  defp read_string(document, key) do
    Map.get(document, key) || Map.get(document, String.to_atom(key))
  end

  defp read_optional_string(document, key) do
    case read_string(document, key) do
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp read_boolean(document, key, default) do
    case read_string(document, key) do
      value when is_boolean(value) -> value
      _ -> default
    end
  end

  defp read_priority(document, key) do
    case read_string(document, key) do
      "low" -> :low
      "high" -> :high
      _ -> :medium
    end
  end

  defp read_tags(document, key) do
    case read_string(document, key) do
      tags when is_list(tags) -> Enum.filter(tags, &is_binary/1)
      _ -> []
    end
  end

  defp read_datetime(document, key) do
    case read_string(document, key) do
      %DateTime{} = datetime ->
        datetime

      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} -> datetime
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp maybe_datetime_to_iso8601(nil), do: nil
  defp maybe_datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp build_filter(filters) do
    %{}
    |> maybe_put_done(filters.done)
    |> maybe_put_priority(filters.priority)
    |> maybe_put_q(filters.q)
    |> maybe_put_tags(filters.tags)
  end

  defp maybe_put_done(filter, nil), do: filter
  defp maybe_put_done(filter, done), do: Map.put(filter, "done", done)

  defp maybe_put_priority(filter, nil), do: filter

  defp maybe_put_priority(filter, priority),
    do: Map.put(filter, "priority", Atom.to_string(priority))

  defp maybe_put_q(filter, nil), do: filter

  defp maybe_put_q(filter, q) do
    regex = %{"$regex" => q, "$options" => "i"}

    Map.put(filter, "$or", [
      %{"title" => regex},
      %{"description" => regex}
    ])
  end

  defp maybe_put_tags(filter, []), do: filter

  defp maybe_put_tags(filter, tags) do
    Map.put(filter, "tags", %{"$all" => tags})
  end
end
