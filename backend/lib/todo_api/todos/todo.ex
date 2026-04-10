defmodule TodoApi.Todos.Todo do
  @moduledoc """
  Domain entity for Todo items.
  """

  @type priority :: :low | :medium | :high

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t(),
          description: String.t() | nil,
          done: boolean(),
          due_date: DateTime.t() | nil,
          priority: priority(),
          tags: [String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @enforce_keys [:title, :done, :priority, :tags, :inserted_at, :updated_at]
  defstruct [
    :id,
    :title,
    :description,
    :due_date,
    :inserted_at,
    :updated_at,
    done: false,
    priority: :medium,
    tags: []
  ]
end
