defmodule TodoApi.Todos.Caches.NoopCache do
  @moduledoc false

  @behaviour TodoApi.Todos.Cache

  @impl true
  def get_list(_filters), do: :miss

  @impl true
  def put_list(_filters, _value), do: :ok

  @impl true
  def invalidate_lists, do: :ok
end
