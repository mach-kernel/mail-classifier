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

  def handle_cast(:async_init, _) do
    Logger.info("Assembling sources")

    job_sources = from(uts in DB.UserTrainingSource) 
                  |> DB.all
                  |> Enum.map(&Corpus.Gmail.start(
                       email: &1.email, target_label: &1.meta["target_label"]
                     ))

    Logger.info("Job messages ready")

    ham_sources = 
      ["20030228_easy_ham.tar.bz2",
       "20030228_easy_ham_2.tar.bz2",
       "20030228_hard_ham.tar.bz2"] |> Enum.map(&Corpus.SpamAssassin.start(&1))

    Logger.info("Ham messages ready")

    {:ok, classifier_pid} = PursuitServices.Classifier.Bayes.start("JobHamSpam")

    {:ok, %{
      job_sources: job_sources,
      ham_sources: ham_sources,
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

  @doc """
    Loop through these collections until one of them runs out of messages
    that we can use to do some training
  """
  def train(%{job_sources: [jh | jt], ham_sources: [hh | ht]} = state) do
    job_message = case find_valid(jh) do
      {:stop, _} -> 
        GenServer.call(jh, :down)
        Map.put(state, :job_sources, jt) |> train
      frame -> frame
    end

    ham_message = case find_valid(hh) do 
      {:stop, _} ->
        GenServer.call(ht, :down)
        Map.put(state, :job_sources, jt) |> train
      frame -> frame
    end

    case {job_message, ham_message} do
      {{:ok, jpid}, {:ok, hpid}} -> 
        send_frame(state.classifier, jpid, hpid)
        train(state)
      _ -> 
        Logger.info("Training complete")
    end
  end

  @doc """
    Loops through the corpus until it can pop a valid message, or until
    a stop signal is yielded
  """
  def find_valid(corpus) do
    case GenServer.call(corpus, :get) do
      {:ok, pid} ->
        case GenServer.call(pid, :body) do 
          "" -> find_valid(corpus)
          _ -> {:ok, pid}
        end
      _ -> {:stop, :empty}
    end
  end
end