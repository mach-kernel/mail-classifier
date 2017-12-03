defmodule PursuitServices.Harness.Mail do
  require Base
  use GenServer

  alias PursuitServices.Shapes
  alias Mail.Parsers.RFC2822
  alias Mail.Message

  @initial_state %{
    message: %Message{},
    mapped: %{},
    meta: %{}
  }

  def start(payload), 
    do: GenServer.start_link(__MODULE__, parse_payload(payload))

  @spec init(map) :: {:ok, map}
  def init(state) do
    try do
      {:ok, Map.put(state, :message, RFC2822.parse(state.rfc_blob))}
    rescue
      RuntimeError -> {:stop, "Cannot parse RFC2822 envelope"}
    end
  end

  def handle_call(:down, _, %{} = s), do: {:stop, "Goodbye!", s}

  ##############################################################################

  # Getters for mapped features

  def handle_call(:body, _, %{mapped: %{ body: d }} = s), do: {:reply, d, s} 
  def handle_call(:features, _, %{mapped: %{features: d}} = s), do: {:reply, d, s}

  ##############################################################################

  # Mapping functions

  def handle_call(:body, _, %{} = state) do 
    sanitized = state.message |> get_body |> HtmlSanitizeEx.strip_tags
    {:reply, sanitized, put_in(state, [:mapped, :body], sanitized)}
  end

  def handle_call(:features, _, %{} = state) do
    cleaned = state.message |> get_body |> tokenize_body
    {:reply, cleaned, put_in(state, [:mapped, :features], cleaned) }
  end

  ##############################################################################  

  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  ##############################################################################

  # Utility functions

  def initial_state, do: @initial_state

  @spec get_body(Message) :: binary
  defp get_body(%Message{} = message) do
    resolved = if message.multipart do
      text_part = Enum.find(message.parts, fn part ->
        [ctype | _] = Message.get_content_type(part)
        ctype == "text/plain"
      end)

      if is_nil(text_part), do: hd(message.parts), else: text_part
    else
      message
    end

    resolved.body
  end

  @spec tokenize_body(binary) :: list(binary)
  defp tokenize_body(body) do
    body |> HtmlSanitizeEx.strip_tags
         |> String.split(" ")
         |> Enum.filter(&(Regex.scan(~r/[^A-Za-z0-9]+/im, &1) |> Enum.empty?))
         |> Enum.uniq
  end

  @spec parse_payload(Shapes.RawMessage) :: map
  defp parse_payload(%Shapes.RawMessage{} = payload),
    do: Map.put(initial_state, :rfc_blob, payload.raw)

  @spec parse_payload(Shapes.GmailMessage) :: map
  defp parse_payload(%Shapes.GmailMessage{} = payload) do
    meta = Map.take(payload, [:id, :threadId])

    initial_state |> Map.replace(:meta, meta)
                  |> Map.put(:rfc_blob, Base.url_decode64!(payload.raw))
  end
end