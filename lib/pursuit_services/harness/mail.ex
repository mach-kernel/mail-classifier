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

  def start(payload), do: GenServer.start_link(__MODULE__, payload)

  @spec init(map) :: {:ok, map}
  def init(%{} = payload) do 
    state = parse_payload(payload)
    state = Map.put(state, :message, RFC2822.parse(state.rfc_blob))
    {:ok, state}
  end

  def handle_call(:down, _, %{} = s), do: {:stop, "Goodbye!", s}

  ##############################################################################

  # Getters for mapped features

  def handle_call(:body, _, %{message: %{ body: d }} = s), do: {:reply, d, s} 
  def handle_call(:features, _, %{mapped: %{features: d}} = s), do: {:reply, d, s}

  ##############################################################################

  # Mapping functions

  def handle_call(:body, _, %{} = state) do 
    sanitized = HtmlSanitizeEx.strip_tags(state.message.body)
    {:reply, sanitized, Map.put(state.mapped, :body, sanitized)}
  end

  def handle_call(:features, _, %{} = state) do
    cleaned = tokenize_body(state.message.body)
    {:reply, cleaned, Map.put(state.mapped, :features, cleaned) }
  end

  ##############################################################################

  # Utility functions

  @spec tokenize_body(binary) :: list(binary)
  defp tokenize_body(body) do
    body |> HtmlSanitizeEx.strip_tags
         |> String.split(" ")
         |> Enum.filter(&(Regex.scan(~r/[^A-Za-z0-9]+/im, &1) |> Enum.empty?))
  end

  @spec parse_payload(Shapes.RawMessage) :: map
  defp parse_payload(%Shapes.RawMessage{} = payload) do
    Map.put(@initial_state, :rfc_blob, Map.get(payload, :raw))
  end

  @spec parse_payload(Shapes.GmailMessage) :: map
  defp parse_payload(%Shapes.GmailMessage{} = payload) do
    meta = Map.take(payload, [:id, :threadId])

    @initial_state |> Map.replace(:meta, meta)
                   |> Map.put(:rfc_blob, Base.url_decode64(payload["raw"]))
  end
end