defmodule Twittex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Twittex.Client.child_spec
    ]

    opts = [strategy: :one_for_one, name: Twittex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
