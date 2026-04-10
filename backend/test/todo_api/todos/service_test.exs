defmodule TodoApi.Todos.ServiceTest do
  use ExUnit.Case, async: false

  alias TodoApi.Todos.Service
  alias TodoApi.Todos.Todo

  setup_all do
    start_agent(TodoApi.Todos.ServiceTest.FakeRepo, fn ->
      TodoApi.Todos.ServiceTest.FakeRepo.default_state()
    end)

    start_agent(TodoApi.Todos.ServiceTest.FakeCache, fn ->
      TodoApi.Todos.ServiceTest.FakeCache.default_state()
    end)

    :ok
  end

  setup do
    TodoApi.Todos.ServiceTest.FakeRepo.reset!()
    TodoApi.Todos.ServiceTest.FakeCache.reset!()

    previous = Application.get_env(:todo_api, :todos)

    Application.put_env(:todo_api, :todos,
      repository: TodoApi.Todos.ServiceTest.FakeRepo,
      cache: TodoApi.Todos.ServiceTest.FakeCache,
      cache_ttl_seconds: 120
    )

    on_exit(fn ->
      Application.put_env(:todo_api, :todos, previous)
    end)

    :ok
  end

  describe "list/1" do
    test "returns cached page on cache hit and skips repository" do
      cached = %{items: [%{"id" => "cached"}], page: 1, page_size: 20, total: 1}
      TodoApi.Todos.ServiceTest.FakeCache.set_get_list_response!({:hit, cached})

      assert {:ok, ^cached} = Service.list(%{})
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:list) == 0
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:put_list) == 0
    end

    test "reads repository on cache miss and writes to cache" do
      page = %{items: [], page: 1, page_size: 20, total: 0}
      TodoApi.Todos.ServiceTest.FakeCache.set_get_list_response!(:miss)
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:list, {:ok, page})

      assert {:ok, ^page} = Service.list(%{"page" => "1"})
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:list) == 1
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:put_list) == 1
    end

    test "returns validation errors and does not call adapters when filters are invalid" do
      assert {:error, {:validation, errors}} =
               Service.list(%{"page" => "0", "done" => "maybe", "priority" => "urgent"})

      assert Map.has_key?(errors, :page)
      assert Map.has_key?(errors, :done)
      assert Map.has_key?(errors, :priority)
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:list) == 0
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:get_list) == 0
    end
  end

  describe "create/1" do
    test "invalidates list cache on successful create" do
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:create, fn todo ->
        %Todo{} = typed_todo = todo
        {:ok, %{typed_todo | id: "new-id"}}
      end)

      assert {:ok, %Todo{id: "new-id"}} =
               Service.create(%{"title" => "new todo", "priority" => "high"})

      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 1
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:create) == 1
    end

    test "does not invalidate cache when create fails" do
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:create, {:error, :db_unavailable})

      assert {:error, :db_unavailable} = Service.create(%{"title" => "new todo"})
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 0
    end

    test "does not call repository when payload is invalid" do
      assert {:error, {:validation, _errors}} = Service.create(%{"title" => "", "done" => "x"})
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:create) == 0
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 0
    end
  end

  describe "update/2" do
    test "invalidates list cache on successful update" do
      existing = sample_todo("todo-1")
      updated = %Todo{existing | done: true}

      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:get, {:ok, existing})
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:update, {:ok, updated})

      assert {:ok, %Todo{done: true}} = Service.update("todo-1", %{"done" => true})
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:get) == 1
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:update) == 1
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 1
    end

    test "does not invalidate cache when get fails" do
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:get, {:error, :not_found})

      assert {:error, :not_found} = Service.update("missing", %{"done" => true})
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:update) == 0
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 0
    end

    test "does not call repository update when attrs are invalid" do
      existing = sample_todo("todo-1")
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:get, {:ok, existing})

      assert {:error, {:validation, errors}} =
               Service.update("todo-1", %{"priority" => "urgent", "done" => "x"})

      assert Map.has_key?(errors, :priority)
      assert Map.has_key?(errors, :done)
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:update) == 0
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 0
    end
  end

  describe "delete/1" do
    test "invalidates list cache on successful delete" do
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:delete, :ok)

      assert :ok = Service.delete("todo-1")
      assert TodoApi.Todos.ServiceTest.FakeRepo.call_count(:delete) == 1
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 1
    end

    test "does not invalidate cache on delete failure" do
      TodoApi.Todos.ServiceTest.FakeRepo.set_result!(:delete, {:error, :not_found})

      assert {:error, :not_found} = Service.delete("todo-1")
      assert TodoApi.Todos.ServiceTest.FakeCache.call_count(:invalidate_lists) == 0
    end
  end

  defp sample_todo(id) do
    now = DateTime.utc_now()

    %Todo{
      id: id,
      title: "todo #{id}",
      description: nil,
      done: false,
      due_date: nil,
      priority: :medium,
      tags: [],
      inserted_at: now,
      updated_at: now
    }
  end

  defp start_agent(name, init_fun) do
    case Agent.start_link(init_fun, name: name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end
end

defmodule TodoApi.Todos.ServiceTest.FakeRepo do
  @behaviour TodoApi.Todos.Repository

  def default_state do
    %{
      results: %{
        list: {:ok, %{items: [], page: 1, page_size: 20, total: 0}},
        get: {:error, :not_found},
        create: {:error, :not_configured},
        update: {:error, :not_configured},
        delete: {:error, :not_configured}
      },
      calls: %{list: 0, get: 0, create: 0, update: 0, delete: 0}
    }
  end

  def reset! do
    Agent.update(__MODULE__, fn _ -> default_state() end)
  end

  def set_result!(name, value) do
    Agent.update(__MODULE__, fn state ->
      put_in(state, [:results, name], value)
    end)
  end

  def call_count(name) do
    Agent.get(__MODULE__, fn state -> Map.fetch!(state.calls, name) end)
  end

  @impl true
  def list(filters), do: call(:list, filters)

  @impl true
  def get(id), do: call(:get, id)

  @impl true
  def create(todo), do: call(:create, todo)

  @impl true
  def update(todo), do: call(:update, todo)

  @impl true
  def delete(id), do: call(:delete, id)

  defp call(name, arg) do
    Agent.get_and_update(__MODULE__, fn state ->
      state = update_in(state, [:calls, name], &(&1 + 1))
      result = Map.fetch!(state.results, name)
      {resolve(result, arg), state}
    end)
  end

  defp resolve(fun, arg) when is_function(fun, 1), do: fun.(arg)
  defp resolve(value, _arg), do: value
end

defmodule TodoApi.Todos.ServiceTest.FakeCache do
  @behaviour TodoApi.Todos.Cache

  def default_state do
    %{
      get_list_response: :miss,
      calls: %{get_list: 0, put_list: 0, invalidate_lists: 0}
    }
  end

  def reset! do
    Agent.update(__MODULE__, fn _ -> default_state() end)
  end

  def set_get_list_response!(value) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, :get_list_response, value)
    end)
  end

  def call_count(name) do
    Agent.get(__MODULE__, fn state -> Map.fetch!(state.calls, name) end)
  end

  @impl true
  def get_list(_filters) do
    Agent.get_and_update(__MODULE__, fn state ->
      state = update_in(state, [:calls, :get_list], &(&1 + 1))
      {state.get_list_response, state}
    end)
  end

  @impl true
  def put_list(_filters, _value) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [:calls, :put_list], &(&1 + 1))
    end)

    :ok
  end

  @impl true
  def invalidate_lists do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [:calls, :invalidate_lists], &(&1 + 1))
    end)

    :ok
  end
end
