defmodule PursuitServices.Corpus do
  @callback start(binary) :: {:ok, pid}

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Corpus

      alias PursuitServices.Harness.Mail

      require Logger

      use GenServer

      def handle_cast(:heartbeat, s) do
        Logger.info("I have #{s.left_in_queue} messages!")
        {:noreply, s}
      end

      @doc """
        Returns the message in a harness GenServer
      """
      def handle_call(:get, _, %{ messages: [h | t] }),
        do: {:reply, Mail.start(h), t}

      def handle_call(:get, _, %{ messages: [] }), do: {:stop, "Out of messages"}
      def handle_call(other, _, s), do: {:reply, :unsupported, s}
    end 
  end
end