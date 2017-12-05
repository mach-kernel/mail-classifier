defmodule PursuitServices.Corpus.SpamAssassin do
  require Logger

  @initial_state %{
    messages: [],
    archive_name: ''
  }

  @base_url "https://spamassassin.apache.org/old/publiccorpus/"

  use PursuitServices.Corpus

  alias PursuitServices.Shapes.RawMessage

  def start(archive_name) do
    {status, pid} = GenServer.start_link(__MODULE__, archive_name: archive_name)

    download = ["wget",
                "-O",
                "#{tmp_dir()}/#{archive_name}",
                "#{@base_url}/#{archive_name}"] |> Enum.join(' ')

    extract = ["cd",
               tmp_dir(),
               "&& tar xvfj #{archive_name}",
               "&& rm #{archive_name}"] |> Enum.join(' ')

    Task.start(fn ->
      System.cmd(download, [])
      System.cmd(extract, [])

      files = Path.wildcard(tmp_dir() <> "/**/*")

      files |> Enum.filter(&File.regular?(&1))
            |> Enum.each(fn f ->
                 Task.start(fn ->
                   GenServer.call(
                     pid,
                     RawMessage.new(raw: File.read!(f))
                   )
                 end)
               end)
    end)

    {status, pid}
  end

  @doc """
    Returns the message in a harness GenServer
  """
  def handle_call(:get, _, %{ messages: [h | t] } = s),
    do: {:reply, Mail.start(h), Map.put(s, :messages, t)}

  def handle_call({:put, %RawMessage{} = message}, _, %{messages: m} = s),
    do: {:reply, :ok, Map.put(s, :messages, [message | m]) } 

  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  defp tmp_dir do
    tmp_path = case File.cwd do
      {:ok, path} -> path
      {:error, _} -> nil
    end

    :ok = File.mkdir_p(tmp_path)

    tmp_path
  end
end