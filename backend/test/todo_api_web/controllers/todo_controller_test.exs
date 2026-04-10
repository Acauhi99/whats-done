defmodule TodoApiWeb.TodoControllerTest do
  use TodoApiWeb.ConnCase, async: true

  import Phoenix.ConnTest

  describe "todo CRUD" do
    test "creates, lists, shows, updates and deletes a todo", %{conn: conn} do
      create_payload = %{
        title: "Write tests",
        description: "cover CRUD",
        priority: "high",
        tags: ["testing"]
      }

      conn = post(conn, ~p"/api/todos", create_payload)
      assert %{"data" => created} = json_response(conn, 201)
      todo_id = created["id"]
      assert get_resp_header(conn, "location") == ["/api/todos/#{todo_id}"]

      conn = get(recycle(conn), ~p"/api/todos")
      assert %{"data" => list, "meta" => meta} = json_response(conn, 200)
      assert length(list) == 1
      assert meta["total"] == 1

      conn = get(recycle(conn), ~p"/api/todos/#{todo_id}")
      assert %{"data" => shown} = json_response(conn, 200)
      assert shown["title"] == "Write tests"

      conn = put(recycle(conn), ~p"/api/todos/#{todo_id}", %{done: true, priority: "medium"})
      assert %{"data" => updated} = json_response(conn, 200)
      assert updated["done"] == true
      assert updated["priority"] == "medium"

      conn = delete(recycle(conn), ~p"/api/todos/#{todo_id}")
      assert response(conn, 204)

      conn = get(recycle(conn), ~p"/api/todos/#{todo_id}")
      assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
    end

    test "returns validation errors when payload is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/todos", %{title: "", priority: "urgent"})

      assert %{"error" => %{"code" => "validation_error", "details" => details}} =
               json_response(conn, 422)

      assert Map.has_key?(details, "title") or Map.has_key?(details, :title)
    end
  end
end
