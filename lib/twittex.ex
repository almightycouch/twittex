defmodule Twittex do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Twittex.Client, [])
    ]

    opts = [strategy: :one_for_one, name: Twittex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
