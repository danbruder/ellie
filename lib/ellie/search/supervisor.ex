defmodule Ellie.Search.Supervisor do

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    import Supervisor.Spec

    children = [
      worker(Ellie.Search.Server, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
