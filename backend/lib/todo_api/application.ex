defmodule TodoApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        TodoApiWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:todo_api, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: TodoApi.PubSub}
      ] ++
        external_clients_children() ++
        [
          # Start a worker by calling: TodoApi.Worker.start_link(arg)
          # {TodoApi.Worker, arg},
          # Start to serve requests, typically the last entry
          TodoApiWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TodoApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TodoApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp mongo_options do
    Application.fetch_env!(:todo_api, :mongo)
    |> Keyword.put_new(:name, TodoApi.Mongo)
  end

  defp redix_options do
    Application.fetch_env!(:todo_api, :valkey)
    |> Keyword.put_new(:name, TodoApi.Valkey)
  end

  defp external_clients_children do
    if Application.get_env(:todo_api, :start_external_clients, true) do
      [{Mongo, mongo_options()}, {Redix, redix_options()}] ++ maybe_index_bootstrap_child()
    else
      []
    end
  end

  defp maybe_index_bootstrap_child do
    if Application.get_env(:todo_api, :ensure_mongo_indexes, true) do
      [
        %{
          id: TodoApi.MongoIndexesTask,
          start:
            {Task, :start_link,
             [fn -> TodoApi.Todos.Repositories.MongoIndexes.ensure_indexes() end]},
          restart: :temporary
        }
      ]
    else
      []
    end
  end
end
