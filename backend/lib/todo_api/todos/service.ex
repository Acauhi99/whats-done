defmodule TodoApi.Todos.Service do
  @moduledoc """
  Imperative shell that orchestrates repository and cache adapters.
  """

  alias TodoApi.Todos.Core

  @spec list(map()) :: {:ok, map()} | {:error, term()}
  def list(params) do
    with {:ok, filters} <- Core.normalize_filters(params) do
      cache = cache_module()

      case cache.get_list(filters) do
        {:hit, value} ->
          {:ok, value}

        :miss ->
          with {:ok, value} <- repository_module().list(filters) do
            :ok = cache.put_list(filters, value)
            {:ok, value}
          end
      end
    end
  end

  @spec get(String.t()) :: {:ok, TodoApi.Todos.Todo.t()} | {:error, term()}
  def get(id), do: repository_module().get(id)

  @spec create(map()) :: {:ok, TodoApi.Todos.Todo.t()} | {:error, term()}
  def create(attrs) do
    with {:ok, todo} <- Core.create(attrs, DateTime.utc_now()),
         {:ok, created} <- repository_module().create(todo) do
      :ok = cache_module().invalidate_lists()
      {:ok, created}
    end
  end

  @spec update(String.t(), map()) :: {:ok, TodoApi.Todos.Todo.t()} | {:error, term()}
  def update(id, attrs) do
    with {:ok, existing} <- repository_module().get(id),
         {:ok, to_save} <- Core.update(existing, attrs, DateTime.utc_now()),
         {:ok, updated} <- repository_module().update(to_save) do
      :ok = cache_module().invalidate_lists()
      {:ok, updated}
    end
  end

  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(id) do
    with :ok <- repository_module().delete(id) do
      :ok = cache_module().invalidate_lists()
      :ok
    end
  end

  defp repository_module do
    Application.fetch_env!(:todo_api, :todos)
    |> Keyword.fetch!(:repository)
  end

  defp cache_module do
    Application.fetch_env!(:todo_api, :todos)
    |> Keyword.fetch!(:cache)
  end
end
