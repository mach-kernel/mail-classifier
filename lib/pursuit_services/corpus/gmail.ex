defmodule PursuitServices.Corpus.Gmail do
  @moduledoc """
    Mounts a mailbox via the Google API and implements standard corpus
    behaviour. The service is immediately started when invoked and populated
    asynchronously
  """

  alias PursuitServices.DB
  alias PursuitServices.Util.REST
  alias PursuitServices.Util.Token
  alias PursuitServices.Shapes.GmailMessage

  import Ecto.Query

  require Logger

  @initial_state %{
    api_args: %{"format" => "raw"},
    email: <<>>,
    messages: []
  }

  use PursuitServices.Corpus

  ##############################################################################
  # Server Initialization
  ##############################################################################

  def init(%{target_label: << target_label :: binary >>} = state) do
    state = state_check_token(state)
    lmeta = state.token["token"] |> REST.Google.labels_list 
                                 |> elem(1)
                                 |> Map.get("labels")
                                 |> Enum.find(&(&1["name"] == target_label))

    updated_args = Map.put(state.api_args, "labelIds", lmeta["id"])

    state |> Map.drop([:target_label])
          |> Map.put(:api_args, updated_args)
          |> init
  end

  def init(state) do
    state = state_check_token(state)
    messages = 
      case REST.Google.messages_list_all(state.token["token"], state.api_args) do
        {:ok, messages} -> messages
        {:error, e} -> 
          Logger.error("Could not mount corpus: #{e}")
          []
      end


    {:ok, Map.put(state, :messages, messages)}
  end

  ##############################################################################
  # Server API
  ##############################################################################

  def handle_call(:get, _, %{ messages: [%{"id" => id} | t] } = s) do
    s = state_check_token(s)

    data = case REST.Google.message(s.token["token"], id, %{"format" => "raw"}) do
      {:ok, blob} -> 
        blob |> GmailMessage.new |> Mail.start
      {:error, %{message: msg}} -> 
        Logger.error("Failed downloading #{id}: (#{msg})")
        :request_failed
      {:error, other} ->
        Logger.error("Server won't serve message: #{other}")
        :request_failed
      _ -> :request_failed
    end

    {:reply, data, Map.put(s, :messages, t)}
  end

  @doc "Don't die on unsupported messages"
  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  ##############################################################################
  # Utility functions
  ##############################################################################

  @spec state_check_token(map) :: map
  def state_check_token(%{token: %{}} = state) do
    if state.token["expires_at"] >= System.system_time(:second) do
      state
    else
      state |> Map.drop([:token]) |> state_check_token
    end
  end

  @spec state_check_token(map) :: map
  def state_check_token(state) do
    tokenset = from(u in DB.User, where: u.email == ^state.email) 
    |> first
    |> DB.one
    |> Token.Google.get
    |> elem(1)


    Map.put(state, :token, tokenset)
  end
end