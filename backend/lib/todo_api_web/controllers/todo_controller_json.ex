defmodule TodoApiWeb.TodoJSON do
  alias TodoApi.Todos.Todo

  def index(%{page: page}) do
    %{
      data: Enum.map(page.items, &todo_json/1),
      meta: %{
        page: page.page,
        page_size: page.page_size,
        total: page.total
      }
    }
  end

  def show(%{todo: todo}) do
    %{data: todo_json(todo)}
  end

  defp todo_json(%Todo{} = todo) do
    %{
      id: todo.id,
      title: todo.title,
      description: todo.description,
      done: todo.done,
      due_date: datetime_to_iso8601(todo.due_date),
      priority: Atom.to_string(todo.priority),
      tags: todo.tags,
      inserted_at: datetime_to_iso8601(todo.inserted_at),
      updated_at: datetime_to_iso8601(todo.updated_at)
    }
  end

  defp todo_json(todo) when is_map(todo) do
    %{
      id: fetch(todo, :id),
      title: fetch(todo, :title),
      description: fetch(todo, :description),
      done: fetch(todo, :done),
      due_date: datetime_to_iso8601(fetch(todo, :due_date)),
      priority: normalize_priority(fetch(todo, :priority)),
      tags: fetch(todo, :tags) || [],
      inserted_at: datetime_to_iso8601(fetch(todo, :inserted_at)),
      updated_at: datetime_to_iso8601(fetch(todo, :updated_at))
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(value) when is_binary(value), do: value
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp normalize_priority(priority) when is_atom(priority), do: Atom.to_string(priority)
  defp normalize_priority(priority), do: priority

  defp fetch(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
