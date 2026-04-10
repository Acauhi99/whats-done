defmodule TodoApi.Todos.Cache do
  @moduledoc """
  Behaviour for Todo list cache adapters.
  """

  @callback get_list(filters :: map()) :: :miss | {:hit, map()}
  @callback put_list(filters :: map(), value :: map()) :: :ok
  @callback invalidate_lists() :: :ok
end
