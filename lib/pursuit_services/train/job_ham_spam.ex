defmodule PursuitServices.Train.JobHamSpam do
  require Logger
  import Ecto.Query
  
  alias PursuitServices.DB
  alias PursuitServices.Corpus

  use GenServer

  def start, do: GenServer.start_link(__MODULE__, [])

  def init(_) do
    GenServer.cast(self(), :async_init)
    {:ok, %{ready: false}}
  end

  def get_job_sources do 
    # from(uts in DB.UserTrainingSource) 
    #   |> DB.all
    #   |> Enum.map(&Task.async(fn -> 
    #                 Corpus.Gmail.start(email: &1.email, 
    #                                    target_label: &1.meta["target_label"])
    #               end))

    a_source = DB.UserTrainingSource |> first |> DB.one
    [a_source] |> Enum.map(&Task.async(fn -> 
                    Corpus.Gmail.start(email: &1.email, 
                                       target_label: &1.meta["target_label"])
                  end))
  end

  def get_ham_sources do
    ham_sources = ["20030228_easy_ham.tar.bz2",
                   "20030228_easy_ham_2.tar.bz2",
                   "20030228_hard_ham.tar.bz2"] 

    Enum.map(ham_sources, &Task.async(fn -> 
      Corpus.SpamAssassin.start(archive_name: &1)
    end))
  end

  def handle_cast(:async_init, _) do
    {:ok, classifier_pid} = PursuitServices.Classifier.Bayes.start("JobHamSpam")

    {:noreply, %{
      job_sources: get_job_sources,
      ham_sources: get_ham_sources,
      classifier: classifier_pid,
      ready: true
    }}
  end

  def handle_cast(:train, %{ready: false} = s) do
    Logger.warn("Not ready to perform training")
    {:ok, s}
  end

  def handle_cast(:train, %{ready: true} = state) do
    train(state)
    {:stop, :complete}
  end

  ##############################################################################
  # Utility functions
  ##############################################################################

  @doc "Dispatch one complete set of training data to classifier"
  def send_frame(classifier_pid, job_pid, ham_pid) do
    Logger.info("Received frame for training")

    {:ok, job_body} = GenServer.call(job_pid, :body)
    {:ok, ham_body} = GenServer.call(ham_pid, :body)

    GenServer.call(classifier_pid, {:train, :job, job_body})
    GenServer.call(classifier_pid, {:train, :ham, ham_body})
  end

  @doc "TODO better way of doing this"
  def train(%{job_sources: []} = state) do
    GenServer.call(state.classifier, :persist)
    GenServer.call(state.classifier, :down)
  end

  def train(classifier_pid, job_pid, ham_pid) do
    {r1, job_msg_pid} = find_valid(job_pid)
    {r2, ham_msg_pid} = find_valid(ham_pid)

    if Enum.any?([r1, r2], &(&1 == :stop)) do
      :stop
    else
      send_frame(classifier_pid, job_msg_pid, ham_msg_pid)
      train(classifier_pid, job_pid, ham_pid)
    end
  end

  @doc """
    Loop through these collections until one of them runs out of messages
    that we can use to do some training
  """
  def train(%{job_sources: [jh | jt], ham_sources: [hh | ht]} = state) do
    train(state.classifier_pid, Task.await(jh), Task.await(hh))
    train(Map.merge(state, %{job_sources: jt, ham_sources: ht}))
  end

  @doc """
    Loops through the corpus until it can pop a valid message, or until
    a stop signal is yielded
  """
  def find_valid({:ok, corpus_pid} = corpus) do
    case GenServer.call(corpus_pid, :get) do
      {:ok, pid} ->
        Logger.info("Popped message from corpus for publishing")
        case GenServer.call(pid, :body) do 
          "" -> find_valid(corpus)
          _ -> {:ok, pid}
        end
      _ -> {:stop, :empty}
    end
  end
end