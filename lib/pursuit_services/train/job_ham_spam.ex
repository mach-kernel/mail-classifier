defmodule PursuitServices.Train.JobHamSpam do
  import Ecto.Query
  alias PursuitServices.DB
  alias PursuitServices.Util.Token
  alias PursuitServices.Util.REST
  alias PursuitServices.Corpus

  use GenServer

  def start, do: GenServer.start_link(__MODULE__, [])

  def init(_) do
    job_sources = from(uts in DB.UserTrainingSource) 
                  |> DB.all
                  |> Enum.map(&Corpus.Gmail.start(&1.email_address, &1.label))

    ham_sources = 
      ["20030228_easy_ham.tar.bz2",
       "20030228_easy_ham_2.tar.bz2",
       "20030228_hard_ham.tar.bz2"] |> Enum.map(&Corpus.SpamAssassin.start(&1))

    {:ok, classifier_pid} = PursuitServices.Classifier.Bayes.start("JobHamSpam")

    {:ok, %{
      job_sources: job_sources,
      ham_sources: ham_sources,
      classifier: classifier_pid
    }}
  end

  def send_frame(classifier_pid, job_pid, ham_pid) do
    {:ok, job_body} = GenServer.call(job_pid, :body)
    {:ok, ham_body} = GenServer.call(ham_pid, :body)

    GenServer.call(classifier_pid, {:train, :job, job_body})
    GenServer.call(classifier_pid, {:train, :ham, ham_body})
  end

  def train(%{job_sources: [jh | jt], ham_sources: [hh | ht]} = state) do
    job_message = case find_valid(jh) do
      {:stop, _} -> Map.put(:job_sources, jt) |> train
      frame -> frame
    end

    ham_message = case(find_valid(hh)) do 
      {:stop, _} -> Map.put(:job_sources, jt) |> train
      frame -> frame
    end

    case {job_message, ham_message} do
      {{:ok, jpid}, {:ok, hpid}} -> 
        send_frame(state.classifier, jpid, hpid)
        train(state)
    end
  end

  def train(%{job_sources: []} = state) do
    GenServer.call(state.classifier, :persist)
    GenServer.call(state.classifier, :down)
  end

  # TODO: Store some sort of progress signal in ETS?
  @doc """
    Invoking the train command should:
      - Train the classifier
      - Clean up the corpus processes
      - Eventually bring down this process
  """
  def handle_cast(:train, _, %{job_sources: [], ham_sources: []} = state) do
    train(state)
    {:stop, :complete}
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