defmodule TodoApi.Todos.Repository do
  @moduledoc """
  Behaviour for Todo persistence operations.
  """

  alias TodoApi.Todos.Todo

  @type page_result :: %{
          items: [Todo.t()],
          page: pos_integer(),
          page_size: pos_integer(),
          total: non_neg_integer()
        }

  @callback list(filters :: map()) :: {:ok, page_result()} | {:error, term()}
  @callback get(id :: String.t()) :: {:ok, Todo.t()} | {:error, :not_found | :invalid_id | term()}
  @callback create(todo :: Todo.t()) :: {:ok, Todo.t()} | {:error, term()}
  @callback update(todo :: Todo.t()) ::
              {:ok, Todo.t()} | {:error, :not_found | :invalid_id | term()}
  @callback delete(id :: String.t()) :: :ok | {:error, :not_found | :invalid_id | term()}
end
