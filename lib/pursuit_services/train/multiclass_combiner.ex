defmodule PursuitServices.Train.MulticlassCombiner do
  use GenServer

  @doc """
    Start a multi-class combiner service used to buffer training data
    to any corpus that matches our API. The corpus controls the messages
    that are allowed to be consumed by this buffering service, and the rate at
    which the combiner receives messages.

    If you cannot keep up with the stream that you are being produced, you can
    tune with the num_combiners argument. The corpus will then broadcast 
    to multiple combiners which then publish to the same sink for training.
  """
  def start(%{} = sources, classifier_pid, num_combiners \\ 1) do
    # Start a supervision tree of combiners
    combiners = 1..num_combiners |> Enum.to_list
    combiners = Enum.map(combiners, fn _ ->
      {__MODULE__, [%{ sources: sources, classifier_pid: classifier_pid }]}
    end)

    # Start the supervision tree, bind the combiners, go to work.
    {:ok, pid} = Supervisor.start_link(combiners, strategy: :one_for_one)

    # Bind the combiners
    sources |> Map.values |> Enum.each(&rebind_combiners(pid, &1))
    {:ok, pid}
  end

  def rebind_combiners(supervisor_pid, corpus_pid) do
    # Get all the PIDs of combiners currently being supervised
    combiner_pids = supervisor_pid |> Supervisor.which_children
                                   |> Enum.map(fn {_, pid, type, _} -> pid end)

    # Rebind a new shuffled stream
    GenServer.call(
      corpus_pid, 
      {:bind_combiners, combiner_pids |> Enum.shuffle |> Stream.cycle}
    )
  end

  
end