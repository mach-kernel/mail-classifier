defmodule PursuitServices.Corpus.SpamAssassin do
  @moduledoc """
    Takes messages from the SpamAssassin open database and wraps them in our
    standardzied parse harness.

    You can check for valid filenames by listing the directory at
    https://spamassassin.apache.org/old/publiccorpus 


    As a convenience, here are some valid ones

    20050311_spam_2.tar.bz2
    20030228_spam.tar.bz2
    20030228_spam_2.tar.bz2
    20030228_easy_ham.tar.bz2
    20030228_easy_ham_2.tar.bz2
    20030228_hard_ham.tar.bz2
  """

  @initial_state %{
    archive_name: <<>>,
    messages: []
  }
  @base_url "https://spamassassin.apache.org/old/publiccorpus"

  use PursuitServices.Corpus
  alias PursuitServices.Shapes.RawMessage

  ##############################################################################
  # Server API
  ##############################################################################

  def handle_cast(:populate_queue, %{archive_name: an} = state) do
    spawn_archive(an, self())
    {:noreply, state}
  end

  def handle_call({:put, %RawMessage{} = message}, _, %{messages: m} = s),
    do: {:reply, :ok, Map.put(s, :messages, [message | m]) } 

  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  ##############################################################################
  # Utility functions
  ##############################################################################

  def spawn_archive(name, pid) do
    # Download
    System.cmd("wget", ["-O", "#{tmp_dir()}/#{name}", "#{@base_url}/#{name}"])

    # Unarchive
    uuid = UUID.uuid4()
    dest_dir = "#{tmp_dir()}/#{uuid}"
    File.mkdir_p(dest_dir)
    System.cmd("tar", ["xvfj", "#{tmp_dir()}/#{name}", "-C", dest_dir])

    # Parallel map into queues
    Path.wildcard("#{tmp_dir()}/#{uuid}/**/*")
      |> Enum.filter(&File.regular?(&1))
      |> Enum.each(fn f ->
           Task.start(fn ->
             GenServer.call(pid, {:put, RawMessage.new(raw: File.read!(f))})
             File.rm_rf(f)
           end)
         end)

    # Nuke directories
    File.rm_rf("#{tmp_dir()}/#{name}")
  end

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