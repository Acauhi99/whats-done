defmodule TodoApiWeb.CorsTest do
  use TodoApiWeb.ConnCase, async: true

  import Phoenix.ConnTest

  test "responds to preflight request with allow-origin header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:5173")
      |> put_req_header("access-control-request-method", "POST")
      |> options(~p"/api/todos")

    assert response(conn, 204)

    assert get_resp_header(conn, "access-control-allow-origin") in [
             ["*"],
             ["http://localhost:5173"]
           ]
  end
end
