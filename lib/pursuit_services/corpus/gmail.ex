defmodule PursuitServices.Corpus.Gmail do
  use GenServer

  @initial_state %{
    email_address: "",
    messages: []
  }

  def start(email_address) do 
    GenServer.start_link(__MODULE__, email_address: email_address)
  end

  def init(state) do
    { :ok, Map.merge(@initial_state, state) }
  end
end