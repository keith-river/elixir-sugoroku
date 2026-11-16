defmodule NiigataSugoroku.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    base_children = [
      NiigataSugorokuWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:niigata_sugoroku, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NiigataSugoroku.PubSub},
      NiigataSugorokuWeb.Endpoint
    ]

    # HOST_NODE=true の場合のみ GameServer を起動
    children =
      if System.get_env("HOST_NODE") == "true" do
        base_children ++ [NiigataSugoroku.GameServer]
      else
        base_children
      end

    opts = [strategy: :one_for_one, name: NiigataSugoroku.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NiigataSugorokuWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
