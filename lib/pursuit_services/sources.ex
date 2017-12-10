defmodule PursuitServices.Sources do
  @callback start(binary) :: {:ok, pid}

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Sources

      alias PursuitServices.Harness.Mail
      require Logger
      use GenServer

      @doc "Start the source service"
      def start(args), 
        do: GenServer.start_link(__MODULE__, Enum.into(args, @initial_state))

      @doc "Produces a log message with important state information"
      def handle_cast(:heartbeat, s) do
        Logger.info("I have #{length(s.messages)} messages!")
        {:noreply, s}
      end

      @doc "Bind training combiners to source."
      def handle_call({:combiner_stream, cs}, state), 
        do: {:reply, :ok, %{state | combiner_stream: cs}}

      @doc "Enable main event loop and publish to the combiner stream"
      def handle_call(:publish_on, _, %{publish: false} = state),
        do: {:reply, :ok, %{state | publish: true}}

      @doc "Disable main event loop."
      def handle_call(:publish_off, _, state),
        do: {:reply, :ok, %{state | publish: false}}

      @doc "Stubbed out handler for when the source runs out of messages"
      def handle_call(:get, _, %{ messages: [] } = s), do: {:stop, :empty, s}

      @doc "Ends the process"
      def handle_call(:down, _, %{} = s), do: {:stop, :normal, s}
    end 
  end
end