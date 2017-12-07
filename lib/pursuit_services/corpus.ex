defmodule PursuitServices.Corpus do
  @callback start(binary) :: {:ok, pid}

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Corpus

      alias PursuitServices.Harness.Mail
      require Logger
      use GenServer

      @callback handle_cast(:populate_queue, Map.t) :: {:noreply, Map.t}

      @doc "Start the corpus service"
      def start(args), 
        do: GenServer.start_link(__MODULE__, Enum.into(args, @initial_state))

      @doc "Spawn initialization routine via an asynchronous cast"
      def init(initial_state) do
        GenServer.cast(self(), :populate_queue)
        {:ok, initial_state}
      end

      @doc "Produces a log message with important state information"
      def handle_cast(:heartbeat, s) do
        Logger.info("I have #{length(s.messages)} messages!")
        {:noreply, s}
      end

      @doc "Returns the message in a harness GenServer"
      def handle_call(:get, _, %{ messages: [h | t] } = s),
        do: {:reply, Mail.start(h), Map.put(s, :messages, t)}
      def handle_call(:get, _, %{ messages: [] } = s), do: {:stop, :empty, s}

      @doc "Ends the process"
      def handle_call(:down, _, %{} = s), do: {:stop, :normal, s}
    end 
  end
end