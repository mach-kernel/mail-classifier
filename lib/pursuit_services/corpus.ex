defmodule PursuitServices.Corpus do
  use GenServer

  def start(servers \\ %{}) do
    GenServer.start_link(__MODULE__, servers)
  end

  def get(repo, corpus, args) do
    GenServer.call(repo, { corpus, args })
  end

  # TBD
  # def handle_call({ :spam_assassin, _ }, from_pid, servers) do
  # end

  def handle_call({ :gmail, address }, _pid, servers) do 
    servers = Map.put_new(
      servers,
      address,
      PursuitServices.Corpus.Gmail.start(address)
    )

    { :reply, servers[address], servers }
  end

  def handle_call(other, _pid, servers) do
    { :reply, :unsupported, servers }
  end
end