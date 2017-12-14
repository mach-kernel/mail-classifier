defmodule PursuitServices.Classifier.MulticlassCombiner do 
  require Logger
  use GenServer

  ##############################################################################
  # Server Initialization
  ##############################################################################

  @doc """
    Expects a map of %{corpus_pid1: label1, corpus_pid2: label2, ...} and the 
    target classifier PID. If your corpora produce at a rate that far exceeds
    the demand asked by the combiner, increasing `num_combiners` will add
    extra competing consumers to your supervision tree.

    Returns a supervisor PID.
  """
  def start(%{} = sources, classifier_pid, num_combiners \\ 1) do 
    combiners = Enum.map(1..num_combiners, fn _ -> 
      Supervisor.child_spec(
        {__MODULE__, %{ sources: sources, classifier_pid: classifier_pid }},
        id: UUID.uuid4()
      )
    end)

    Supervisor.start_link(combiners, strategy: :one_for_one)
  end

  @doc "Starts the combiner process"
  def start_link(%{sources: srcs} = state) do
    GenServer.start_link(
      __MODULE__, 
      srcs |> Map.values
           |> Enum.reduce(state, &(&2 |> Map.put(&1, [])))
    )
  end

  @doc "Begin the event loop upon up"
  def init(state) do
    GenServer.cast(self(), :send_train_data)
    {:ok, state}
  end

  ##############################################################################
  # Server API
  ##############################################################################

  @doc "Add a message to its labeled queue"
  def handle_call({:put, message}, {from_pid, _}, %{sources: srcs} = s) do
    label = srcs[from_pid]
    {:reply, :ok, %{ s | label => [ message | s[label] ]}}
  end

  @doc """
    Primary event loop: send messages to the trainer in batches until one of 
    our sources runs out.
  """
  def handle_cast(:send_train_data, %{sources: srcs, classifier_pid: cp} = s) do
    :timer.sleep(50)
    queue_set = s |> Map.take(Map.values(srcs))

    # log_queue_set(queue_set)

    train_set = Enum.map(queue_set, fn {label, queue} ->
      case queue do
        [ frame | _ ] -> {label, frame}
        [] -> :stop
      end
    end)

    mapped_state = Enum.map(queue_set, fn {label, queue} ->
                     case queue do
                       [ _ | rest ] -> {label, rest}
                       _ -> {label, []}
                     end
                   end) |> Enum.into(%{})

    # We will just not publish anything (for now) if out of messages
    if not Enum.any?(train_set, &(&1 == :stop)) do     
      Logger.info("Received training frame!")
      GenServer.call(cp, {:train, train_set})
    end

    GenServer.cast(self(), :send_train_data)

    # Update queue
    {:noreply, Map.merge(s, mapped_state)}
  end

  defp log_queue_set(queue_set) do
    Enum.each(queue_set,
      &Logger.info("#{length(elem(&1, 1))} #{elem(&1, 0)} messages left")
    )
  end
end