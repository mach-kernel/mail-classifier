defmodule PursuitServices.Corpus.Gmail do
  require Logger

  alias PursuitServices.Util.REST.Google
  alias PursuitServices.DB
  alias PursuitServices.Shapes.GmailMessage

  use PursuitServices.Corpus

  import Ecto.Query

  @initial_state %{
    email_address: "",
    messages: [],
    # Since we're wrapping this in a stream, it is lazy evaluated and invoking
    # any length function will involve the execution of the futures. Like this,
    # we only map when we are ready to consume!
    left_in_queue: 0
  }

  def start(email_address) do 
    {_, token} = PursuitServices.Util.Token.Google.get(
      from(u in DB.User, where: u.email == ^email_address, limit: 1) |> DB.one
    )

    case Google.messages_list_all(token["token"]) do
      {:ok, messages} ->
        require IEx

        IEx.pry

        messages = Enum.map(messages, fn m ->
          Task.async(fn -> 
            case Google.message(token["token"], m["id"]) do 
              {:ok, blob} -> GmailMessage.new(blob)
              {:error, _} -> 
                Logger.error("Could not download message: #{m["id"]}")
            end
          end)
        end)

        GenServer.start_link(
          __MODULE__,
          email_address: email_address, 
          messages: messages,
          left_in_queue: length(messages)
        )

      {:error, _} -> Logger.error("Could not mount corpus")
    end
  end

  def init(args) do
    { :ok, Enum.into(args, @initial_state) }
  end
end