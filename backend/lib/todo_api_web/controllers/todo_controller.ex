defmodule TodoApiWeb.TodoController do
  use TodoApiWeb, :controller

  alias TodoApi.Todos

  action_fallback TodoApiWeb.FallbackController

  def index(conn, params) do
    with {:ok, page} <- Todos.list(params) do
      render(conn, :index, page: page)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, todo} <- Todos.get(id) do
      render(conn, :show, todo: todo)
    end
  end

  def create(conn, params) do
    with {:ok, todo} <- Todos.create(extract_payload(params)) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/todos/#{todo.id}")
      |> render(:show, todo: todo)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, todo} <- Todos.update(id, extract_payload(params)) do
      render(conn, :show, todo: todo)
    end
  end

  def delete(conn, %{"id" => id}) do
    with :ok <- Todos.delete(id) do
      send_resp(conn, :no_content, "")
    end
  end

  defp extract_payload(%{"todo" => payload}) when is_map(payload), do: payload

  defp extract_payload(params) when is_map(params) do
    Map.drop(params, ["id"])
  end
end
