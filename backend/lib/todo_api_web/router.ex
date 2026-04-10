defmodule TodoApiWeb.Router do
  use TodoApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TodoApiWeb do
    pipe_through :api

    get "/health", HealthController, :index

    resources "/todos", TodoController, except: [:new, :edit]
  end
end
