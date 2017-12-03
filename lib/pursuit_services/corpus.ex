defmodule PursuitServices.Corpus do
  @callback start(binary) :: {:ok, pid}

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Corpus

      alias PursuitServices.Harness.Mail

      require Logger

      use GenServer

      def init(args), do: { :ok, Enum.into(args, @initial_state) }

      def handle_cast(:heartbeat, s) do
        Logger.info("I have #{length(s.messages)} messages!")
        {:noreply, s}
      end

      def handle_call(:get, _, %{ messages: [] } = s), 
        do: {:stop, "Out of messages", s}
    end 
  end
end