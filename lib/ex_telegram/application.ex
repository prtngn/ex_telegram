defmodule ExTelegram.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExTelegram.Client, nil}
    ]

    opts = [strategy: :one_for_one, name: ExTelegram.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
