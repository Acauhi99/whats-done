defmodule TodoApi.Todos.Caches.ValkeyCacheTest do
  use ExUnit.Case, async: false

  alias TodoApi.Todos.Caches.ValkeyCache
  alias TodoApi.Todos.Todo

  @moduletag :integration

  setup_all do
    host = System.get_env("VALKEY_HOST", "localhost")
    port = String.to_integer(System.get_env("VALKEY_PORT", "6379"))
    password = System.get_env("VALKEY_PASSWORD", "valkey-local-pass")

    options = [name: TodoApi.Valkey, host: host, port: port, password: password]

    case Redix.start_link(options) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> raise "could not start valkey client: #{inspect(other)}"
    end

    :ok
  end

  setup do
    {:ok, "OK"} = Redix.command(TodoApi.Valkey, ["FLUSHDB"])
    :ok
  end

  test "returns miss when key is absent" do
    assert :miss = ValkeyCache.get_list(filters(1))
  end

  test "returns hit after storing a list payload" do
    page = %{
      items: [
        %Todo{
          id: "1",
          title: "cache item",
          description: "from valkey",
          done: false,
          due_date: nil,
          priority: :high,
          tags: ["cache"],
          inserted_at: ~U[2026-01-01 00:00:00Z],
          updated_at: ~U[2026-01-01 00:00:00Z]
        }
      ],
      page: 1,
      page_size: 20,
      total: 1
    }

    assert :ok = ValkeyCache.put_list(filters(1), page)
    assert {:hit, cached_page} = ValkeyCache.get_list(filters(1))

    assert cached_page.total == 1
    assert cached_page.page == 1
    assert length(cached_page.items) == 1

    assert [%{"title" => "cache item", "priority" => "high"}] =
             Enum.map(cached_page.items, &Map.take(&1, ["title", "priority"]))
  end

  test "invalidates all list keys" do
    assert :ok = ValkeyCache.put_list(filters(1), %{items: [], page: 1, page_size: 20, total: 0})
    assert :ok = ValkeyCache.put_list(filters(2), %{items: [], page: 2, page_size: 20, total: 0})

    {:ok, keys_before} = Redix.command(TodoApi.Valkey, ["KEYS", "todos:list:*"])
    assert length(keys_before) == 2

    assert :ok = ValkeyCache.invalidate_lists()

    {:ok, keys_after} = Redix.command(TodoApi.Valkey, ["KEYS", "todos:list:*"])
    assert keys_after == []
  end

  defp filters(page) do
    %{page: page, page_size: 20, done: nil, priority: nil, q: nil, tags: []}
  end
end
