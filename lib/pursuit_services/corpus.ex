defmodule PursuitServices.Corpus do
  @callback start(binary) :: {:ok, pid}

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Corpus

      alias PursuitServices.Harness.Mail
      require Logger
      use GenServer

      @doc "Start the corpus service"
      def start(args), 
        do: GenServer.start_link(__MODULE__, Enum.into(args, @initial_state))

      @doc "Produces a log message with important state information"
      def handle_cast(:heartbeat, s) do
        Logger.info("I have #{length(s.messages)} messages!")
        {:noreply, s}
      end

      @doc "Stubbed out handler for when the corpus runs out of messages"
      def handle_call(:get, _, %{ messages: [] } = s), do: {:stop, :empty, s}

      @doc "Ends the process"
      def handle_call(:down, _, %{} = s), do: {:stop, :normal, s}
    end 
  end
end