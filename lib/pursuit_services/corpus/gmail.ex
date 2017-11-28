defmodule PursuitServices.Corpus.Gmail do
  alias PursuitServices.Util.REST.Google
  alias PursuitServices.DB

  import Ecto.Query
  require Logger

  use GenServer

  @initial_state %{
    email_address: "",
    messages: []
  }

  def start(email_address) do 
    {:ok, pid} = GenServer.start_link(__MODULE__, email_address: email_address)

    {_, token} = PursuitServices.Util.Token.Google.get(
      from(u in DB.User, where: u.email == ^email_address, limit: 1) |> DB.one
    )

    {:ok, messages} = Google.messages_list_all(token["token"])

    Enum.each(messages, fn(m) ->
      spawn(fn ->
        case Google.message(token["token"], m["id"]) do 
          {:ok, blob} -> GenServer.cast(pid, {:add_downloaded_message, blob})
          {:error, _} -> Logger.error("Could not download message: #{m["id"]}")
        end
      end)
    end)

    {:ok, pid}
  end

  def init(state) do
    { :ok, Map.merge(@initial_state, Map.new(state)) }
  end

  def handle_cast(:heartbeat, s) do
    Logger.info("I have #{length(s.messages)} messages!")
    {:noreply, s}
  end

  def handle_cast({:add_downloaded_message, blob}, state) do
    if rem(length(state.messages), 100) == 0, do: Logger.info(
      "Last message received was #{blob["id"]}, #{length(state.messages)} total"
    )
    {:noreply, Map.merge(state, %{messages: [blob | state.messages]}) }
  end
end