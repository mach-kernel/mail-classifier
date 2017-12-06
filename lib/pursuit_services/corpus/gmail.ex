defmodule PursuitServices.Corpus.Gmail do
  require Logger

  alias PursuitServices.Util.REST
  alias PursuitServices.Util.Token

  alias PursuitServices.Shapes.GmailMessage

  @initial_state %{ email_address: "", messages: [] }
  use PursuitServices.Corpus

  @doc """
    Create a service process containing all of the email messages inside the
    requested inbox. Spawns isolated async tasks which do not get linked
    to the calling process.
  """
  @spec start(binary, map) :: {:ok, pid}
  def start(email_address, args \\ %{})

  @spec start(binary, binary) :: {:ok, pid}
  def start(email_address, target_label) when is_binary(target_label) do
    label_id = email_address |> Token.Google.get_from_email 
                             |> REST.Google.labels_list
                             |> Map.get("labels")
                             |> Enum.find(&(&1["name"] == target_label))
                             |> Map.get("id")

    args = if is_nil(label_id), do: nil, else: %{labelIds: label_id}
    start(email_address, args)
  end

  def start(email_address, %{} = args) do
    {status, pid} = 
      GenServer.start_link(__MODULE__, email_address: email_address)

    args = Map.merge(args, %{"format" => "raw"})
    token = Token.Google.get_from_email(email_address)

    case REST.Google.messages_list_all(token) do
      {:ok, messages} -> Enum.each(messages, &find_message(&1["id"], args, token, pid))
      {:error, e} -> Logger.error("Could not mount corpus: #{e}")
    end

    {status, pid}
  end

  # Asynchronously dispatch the map operation of ID -> complete frame
  defp find_message(id, %{} = args, token, pid) do
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

  @doc """
    Returns the message in a harness GenServer
  """
  def handle_call(:get, _, %{ messages: [h | t] } = s),
    do: {:reply, Mail.start(h), Map.put(s, :messages, t)}

  @doc """
    The corpus collection is populated concurrently, a GMail API response
    can be added to the collection via this GenServer call
  """
  def handle_call({:put, %GmailMessage{} = message}, _, %{messages: m} = s),
    do: {:reply, :ok, Map.put(s, :messages, [message | m]) }  

  def handle_call(_, _, s), do: {:reply, :unsupported, s}
end