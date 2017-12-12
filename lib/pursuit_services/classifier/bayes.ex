defmodule PursuitServices.Classifier.Bayes do
  alias PursuitServices.DB
  alias PursuitServices.DB.ClassifierCorpus

  alias PursuitServices.Harness.Mail

  import Ecto.Query
  require Logger

  use GenServer

  def start(name) do
    latest = from(c in ClassifierCorpus, order_by: [desc: :updated_at])
             |> first 
             |> DB.one


    latest = if is_nil(latest) do 
      case DB.insert(%ClassifierCorpus{
        name: name, classifier_type: "Bayes", object: ""
      }) do
        {:ok, corpus_record} -> corpus_record
        {:error, _} -> nil
      end
    else
      latest
    end

    GenServer.start_link(__MODULE__, latest)
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

  def handle_call({:train, batch}, _, state) do
    Enum.each(batch, fn {label, data} ->
      case Mail.start(data) do
        {:ok, harness_pid} ->
          Logger.info("Received training frame for #{label}")

          SimpleBayes.train(
            state.classifier_pid,
            label, 
            GenServer.call(harness_pid, :body)
          )

          # It gets touchy about this?
          # GenServer.call(harness_pid, :down)
        _ -> 
          Logger.warn("Discarded message during training")
      end
    end)

    {:reply, :ok, state}
  end

  def handle_call({:classify, data}, _, state), do:
    {:reply, SimpleBayes.classify(state.classifier_pid, data), state}
end