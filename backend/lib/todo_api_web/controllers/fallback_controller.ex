defmodule TodoApiWeb.FallbackController do
  use TodoApiWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{code: "not_found", message: "resource not found"}})
  end

  def call(conn, {:error, :invalid_id}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "invalid_id", message: "id must be a valid object id"}})
  end

  def call(conn, {:error, {:validation, details}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "validation_error", details: details}})
  end

  def call(conn, {:error, reason}) do
    _ = reason

    conn
    |> put_status(:internal_server_error)
    |> json(%{error: %{code: "internal_error", message: "internal server error"}})
  end
end
