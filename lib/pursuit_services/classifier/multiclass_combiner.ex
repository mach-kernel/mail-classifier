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


  @doc "Creates empty queues for each label as part of state initialization"
  def start_link(%{sources: srcs} = state) do
    state_with_labels = srcs |> Map.values
                             |> Enum.reduce(state, &(&2 |> Map.put(&1, [])))

    GenServer.start_link(__MODULE__, Map.merge(state, state_with_labels))
  end

  ##############################################################################
  # Server API
  ##############################################################################

  @doc "Add a message to its labeled queue"
  def handle_call({:put, message}, from_pid, %{sources: srcs} = s) do
    label = srcs[from_pid]
    {:reply, :ok, %{ s | label => [ message | s[label] ]}}
  end

  @doc """
    Primary event loop: send messages to the trainer in batches until one of 
    our sources runs out.
  """
  def handle_cast(:send_train_data, %{sources: srcs, classifier_pid: cp} = s) do
    :timer.sleep(1000)
    queue_set = s |> Map.take(Map.values(srcs))

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
    end)

    # We will just not publish anything (for now) if out of messages
    if not Enum.any?(train_set, &(&1 == :stop)) do
      GenServer.call(cp, {:train, train_set})
      svc_pid = self()
      spawn(fn -> GenServer.cast(svc_pid, :send_train_data) end)
    end

    # Update queue
    {:noreply, Map.merge(s, mapped_state)}
  end
end