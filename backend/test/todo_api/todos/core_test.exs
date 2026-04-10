defmodule TodoApi.Todos.CoreTest do
  use ExUnit.Case, async: true

  alias TodoApi.Todos.Core

  describe "create/2" do
    test "builds a todo from valid attrs" do
      now = DateTime.utc_now()

      attrs = %{
        "title" => "Implement API",
        "description" => "Build todo endpoints",
        "done" => false,
        "priority" => "high",
        "tags" => ["backend", "elixir"]
      }

      assert {:ok, todo} = Core.create(attrs, now)
      assert todo.title == "Implement API"
      assert todo.priority == :high
      assert todo.tags == ["backend", "elixir"]
      assert todo.inserted_at == now
      assert todo.updated_at == now
    end

    test "returns accumulated validation errors on invalid attrs" do
      attrs = %{"title" => "", "priority" => "urgent", "done" => "yes"}

      assert {:error, {:validation, errors}} = Core.create(attrs, DateTime.utc_now())
      assert Map.has_key?(errors, :title)
      assert Map.has_key?(errors, :priority)
      assert Map.has_key?(errors, :done)
    end
  end

  describe "update/3" do
    test "updates only provided fields" do
      now = DateTime.utc_now()

      {:ok, todo} =
        Core.create(%{"title" => "Initial", "priority" => "low", "tags" => ["a"]}, now)

      later = DateTime.add(now, 120, :second)
      assert {:ok, updated} = Core.update(todo, %{"done" => true, "priority" => "medium"}, later)

      assert updated.title == "Initial"
      assert updated.done == true
      assert updated.priority == :medium
      assert updated.updated_at == later
    end

    test "returns accumulated errors when multiple optional fields are invalid" do
      now = DateTime.utc_now()
      {:ok, todo} = Core.create(%{"title" => "Initial"}, now)

      assert {:error, {:validation, errors}} =
               Core.update(todo, %{"priority" => "urgent", "done" => "y", "tags" => "bad"}, now)

      assert Map.has_key?(errors, :priority)
      assert Map.has_key?(errors, :done)
      assert Map.has_key?(errors, :tags)
    end
  end

  describe "normalize_filters/1" do
    test "normalizes valid filter params" do
      params = %{"page" => "2", "page_size" => "10", "done" => "true", "priority" => "medium"}

      assert {:ok, filters} = Core.normalize_filters(params)
      assert filters.page == 2
      assert filters.page_size == 10
      assert filters.done == true
      assert filters.priority == :medium
    end

    test "returns accumulated errors for invalid filter params" do
      assert {:error, {:validation, errors}} =
               Core.normalize_filters(%{"page" => "0", "page_size" => "150", "done" => "nope"})

      assert Map.has_key?(errors, :page)
      assert Map.has_key?(errors, :page_size)
      assert Map.has_key?(errors, :done)
    end
  end
end
