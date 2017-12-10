defmodule PursuitServices.Sources do
  @moduledoc """
    This is a behaviour for a standard Pursuit SoA message source. Each source
    can be treated as a repository: demand messages using the API defined in 
    the macro block.

    Additionally, you can also specify a stream of combiners
    that are used in training to automatically process and spawn messages. This
    is a performance optimization: it is faster to asynchronously cast messages
    into a buffered mailbox for further processing than it is to deschedule the 
    process until you ask for one message at random intervals. The work is not
    intensive enough for the scheduler to prioritize so you end up waiting on 
    the handshake. Cut the handshake time out for maximum pipelining.
  """

  alias PursuitServices.Shapes

  @doc """
    Since the Gmail adapter doesn't give us completed frames, we need to do
    some kind of mapping on send. This has the added benefit of making the 
    users of this module not have to worry about the actor abstraction.

    Must return one of the supported message shapes.
  """
  @callback map_message(any, map) :: Shapes.RawMessage.t | 
                                     Shapes.GmailMessage.t

  defmacro __using__(_) do
    quote do
      @behaviour PursuitServices.Sources

      alias PursuitServices.Harness.Mail
      require Logger
      use GenServer

      @state_schema %{
        messages: [],
        publish: false,
        combiner_supervisor: nil
      }

      @doc "Start the source service"
      def start(args), 
        do: GenServer.start_link(
              __MODULE__, 
              @state_schema |> Map.merge(Enum.into(args, @initial_state))
            )

      ##########################################################################
      # Server API (information)
      ##########################################################################

      @doc "Produces a log message with important state information"
      def handle_cast(:heartbeat, s) do
        Logger.info("I have #{length(s.messages)} messages!")
        {:noreply, s}
      end

      ##########################################################################
      # Server API (publish mechanism)
      ##########################################################################

      @doc """
        When publishing is disabled, we don't keep popping messages off of the 
        queue and just drop the demand.
      """
      def handle_cast(:publish, %{publish: false} = s), do: {:noreply, s}

      @doc """
        Main event loop. Publishes messages to combiners while allowed.
      """
      def handle_cast(
        :publish, 
        %{combiner_supervisor: cs, messages: [h | t], publish: true} = s
      ) do

        # Yields a list of tuples {_, pid, worker_type, _} where we don't care
        # about _
        cs |> Supervisor.which_children
           |> Enum.map(&Kernel.elem(&1, 1))
           |> Enum.shuffle
           |> Enum.each(
                &GenServer.cast(&1, map_message(h, s |> Map.drop([:messages])))
              )

        svc_pid = self()
        spawn(fn -> GenServer.cast(:publish, svc_pid) end)

        {:noreply, %{s | messages: t}}
      end

      @doc "Bind training combiners to source."
      def handle_call({:bind_combiner_supervisor, cs}, _, state), 
        do: {:reply, :ok, %{state | combiner_supervisor: cs}}

      @doc "Do not attempt to publish without a stream"
      def handle_call(:publish_on, _, %{combiner_supervisor: nil} = state),
        do: {:reply, :unbound_stream, state}

      @doc "Enable main event loop and publish to the combiner stream"
      def handle_call(:publish_on, _, %{publish: false} = state),
        do: {:reply, :ok, %{state | publish: true}}

      @doc "Disable main event loop."
      def handle_call(:publish_off, _, state),
        do: {:reply, :ok, %{state | publish: false}}

      ##########################################################################
      # Server API (repository mechanism)
      ##########################################################################

      @doc "Map and pop a message from the queue"
      def handle_call(:get, _, %{ messages: [ h | t ] } = s), do: 
        {:reply, map_message(h, s |> Map.drop([:messages])), %{s | messages: t}}

      @doc "Stubbed out handler for when the source runs out of messages"
      def handle_call(:get, _, %{ messages: [] } = s), do: {:stop, :empty, s}

      @doc "Ends the process"
      def handle_call(:down, _, %{} = s), do: {:stop, :normal, s}
    end 
  end
end