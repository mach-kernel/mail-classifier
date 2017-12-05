defmodule PursuitServices.Classifier.Bayes do
  alias PursuitServices.DB
  alias PursuitServices.DB.ClassifierCorpus

  import Ecto.Query
  use GenServer

  def start do 
    latest = from(c in ClassifierCorpus, order_by: [desc: :updated_at])
             |> first 
             |> DB.one

    if is_nil(latest), do: {:error, "Must train a corpus"},
                       else: GenServer.start_link(__MODULE__, latest)
  end

  def start(data_tag) do
    case DB.insert(%ClassifierCorpus{
      data_id: data_tag,
      classifier_type: "Bayes",
      object: ""
    }) do
      {:ok, corpus_record} -> GenServer.start_link(__MODULE__, corpus_record)
      {:error, _} -> {:error, "Could not make new corpus record"}
    end
  end

  def init(%ClassifierCorpus{object: <<>>} = corpus),
    do: {:ok, %{ corpus_id: corpus.id, classifier_pid: SimpleBayes.init() } }

  def init(%ClassifierCorpus{object: cobject} = corpus),
    do: {:ok, %{ corpus_id: corpus.id,
                 classifier_pid: SimpleBayes.load(encoded_data: cobject)} }

  def handle_call(:persist, _, state) do
    {:ok, _, data} = SimpleBayes.save(state.classifier_pid)
    
    case DB.insert(%ClassifierCorpus {id: state.id, object: data }) do
      {:ok, _} -> {:noreply, state}
      _ -> {:reply, :failed, state}
    end
  end

  def handle_call(:down, _, state) do
    Process.exit(state.classifier_pid, :normal)
    {:stop, :normal}
  end

  def handle_call({:train, category, data}, _, state) do 
    SimpleBayes.train(state.classifier_pid, category, data)
    {:reply, :ok, state}
  end

  def handle_call({:classify, data}, _, state), do:
    {:reply, SimpleBayes.classify(state.classifier_pid, data), state}
end