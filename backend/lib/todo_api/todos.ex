defmodule TodoApi.Todos do
  @moduledoc """
  Public context for Todo use-cases.
  """

  alias TodoApi.Todos.Service

  defdelegate list(params), to: Service
  defdelegate get(id), to: Service
  defdelegate create(attrs), to: Service
  defdelegate update(id, attrs), to: Service
  defdelegate delete(id), to: Service
end
