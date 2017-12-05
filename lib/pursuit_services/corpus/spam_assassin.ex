defmodule PursuitServices.Corpus.SpamAssassin do
  require Logger

  @initial_state %{
    messages: [],
    archive_name: ''
  }

  @base_url "https://spamassassin.apache.org/old/publiccorpus"

  use PursuitServices.Corpus

  alias PursuitServices.Shapes.RawMessage

  def start(archive_name) do
    {status, pid} = GenServer.start_link(__MODULE__, archive_name: archive_name)
    Task.start(fn ->
      System.cmd("wget", ["-O",
                          "#{tmp_dir()}/#{archive_name}",
                          "#{@base_url}/#{archive_name}"])

      uuid = UUID.uuid4()
      dest_dir = "#{tmp_dir()}/#{uuid}"
      File.mkdir_p(dest_dir)

      System.cmd("tar", ["xvfj",
                         "#{tmp_dir()}/#{archive_name}",
                         "-C",
                         dest_dir])

      files = Path.wildcard("#{tmp_dir()}/#{uuid}/**/*")

      files |> Enum.filter(&File.regular?(&1))
            |> Enum.each(fn f ->
                 Task.start(fn ->
                   GenServer.call(
                     pid, {:put, RawMessage.new(raw: File.read!(f))}
                   )

                   File.rm_rf(f)
                 end)
               end)

      File.rm_rf("#{tmp_dir()}/#{archive_name}")
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
    cwd = case File.cwd do
      {:ok, path} -> path
      {:error, _} -> nil
    end

    fullpath = cwd <> "/tmp"
    :ok = File.mkdir_p(fullpath)

    fullpath
  end
end