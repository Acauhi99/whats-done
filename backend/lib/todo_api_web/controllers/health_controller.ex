defmodule TodoApiWeb.HealthController do
  use TodoApiWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
