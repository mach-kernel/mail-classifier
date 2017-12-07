defmodule PursuitServices.Corpus.Gmail do
  @moduledoc """
    Mounts a mailbox via the Google API and implements standard corpus
    behaviour. The service is immediately started when invoked and populated
    asynchronously
  """

  alias PursuitServices.Util.REST
  alias PursuitServices.Util.Token
  alias PursuitServices.Shapes.GmailMessage

  @initial_state %{
    email: <<>>,
    messages: []
  }

  use PursuitServices.Corpus

  ##############################################################################
  # Server API
  ##############################################################################

  def handle_cast(:populate_queue, %{email: email} = state) do
    token = Token.Google.get_from_email(email)
    api_args = %{"format" => "raw"}

    target_label = state["target_label"]
    if !is_nil(target_label) do 
      lmeta = token |> REST.Google.labels_list 
                    |> elem(1)
                    |> Map.get("labels")
                    |> Enum.find(&(&1["name"] == target_label))

      Map.put(api_args, "labelIds", lmeta["id"])
    end

    case REST.Google.messages_list_all(token) do
      {:ok, messages} ->
        Logger.info("Got here")
        Enum.each(messages, &find_message(&1["id"], api_args, token, self()))
      {:error, e} -> 
        Logger.error("Could not mount corpus: #{e}")
    end

    {:noreply, state}
  end

  @doc """
    The corpus collection is populated concurrently, a GMail API response
    can be added to the collection via this GenServer call
  """
  def handle_call({:put, %GmailMessage{} = message}, _, %{messages: m} = s),
    do: {:reply, :ok, Map.put(s, :messages, [message | m]) }  

  @doc "Don't die on unsupported messages"
  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  ##############################################################################
  # Utility functions
  ##############################################################################

  @doc "Asynchronously dispatch the map operation of ID -> complete frame"
  def find_message(id, %{} = args, token, pid) do
    Task.start(fn ->
      case REST.Google.message(token, id, args) do
        {:ok, blob} ->
          # We want to try and offset the time we make the requests to 
          # lean into the rate limit slower
          :timer.sleep(round(1000 * :rand.uniform))
          GenServer.call(pid, {:put, GmailMessage.new(blob)}, 1000 * 30 * 60)
        {:error, %{message: msg}} -> 
          Logger.error("Failed downloading #{id}: (#{msg})")
        {:error, other} ->
          Logger.error("Server won't serve message: #{other}")
      end
    end)
  end
end