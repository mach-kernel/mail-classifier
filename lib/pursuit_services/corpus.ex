defmodule PursuitServices.Corpus do
  require Logger

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Corpus

      use GenServer
      require Logger
    end 
  end

  @callback start(bitstring) :: {:ok, pid}

  def handle_cast(:heartbeat, s) do
    Logger.info("I have #{length(s.messages)} messages!")
    {:noreply, s}
  end
end