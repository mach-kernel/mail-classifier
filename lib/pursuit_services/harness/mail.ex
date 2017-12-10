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

  @doc "Spawns a corpus service, but does not link it to your supervision tree"
  def start(payload) do
    parsed = parse_payload(payload)

    try do 
      # For some reason, "Windows-style" returns are treated differently
      message = if Regex.match?(~r/\r\n/, parsed.rfc_blob) do
        RFC2822.parse(parsed.rfc_blob)
      else
        parsed.rfc_blob |> String.split("\n") |> RFC2822.parse
      end

      GenServer.start(__MODULE__, Map.put(parsed, :message, message))
    rescue
      _ -> :cannot_parse      
    end
  end
    
  ##############################################################################
  # Server API
  ##############################################################################

  def handle_call(:down, _, %{} = s), do: {:stop, :normal, s}
  def handle_call(:body, _, %{mapped: %{ body: d }} = s), do: {:reply, d, s} 
  def handle_call(:features, _, %{mapped: %{features: d}} = s), do: {:reply, d, s}

  def handle_call(:body, _, %{} = state) do
    sanitized = state.message |> get_body |> HtmlSanitizeEx.strip_tags
    {:reply, sanitized, put_in(state, [:mapped, :body], sanitized)}
  end

  def handle_call(:features, _, %{} = state) do
    cleaned = state.message |> get_body |> tokenize_body
    {:reply, cleaned, put_in(state, [:mapped, :features], cleaned) }
  end

  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  ##############################################################################
  # Utility functions
  ##############################################################################

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
  defp parse_payload(%Shapes.RawMessage{} = payload) do
    Map.put(initial_state(), :rfc_blob, payload.raw)
  end

  @spec parse_payload(Shapes.GmailMessage) :: map
  defp parse_payload(%Shapes.GmailMessage{} = payload) do
    meta = Map.take(payload, [:id, :threadId])

    initial_state() |> Map.replace(:meta, meta)
                    |> Map.put(:rfc_blob, Base.url_decode64!(payload.raw))
  end
end