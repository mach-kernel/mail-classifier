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

  def init(state) do
    populate_queue(state)
    {:ok, state}
  end

  ##############################################################################
  # Server API
  ##############################################################################

  @doc "Asynchronously invoke the spawn job to populate the queue"
  def handle_cast(:populate_queue, %{archive_name: _} = state) do
    populate_queue(state)
    {:noreply, state}
  end

  @doc "Retrieve a message from the corpus"
  def handle_call(:get, _, %{messages: [ h | t]} = state) do
    {:reply, Mail.start(h), Map.put(state, :messages, t)}
  end

  # TODO: Enumerate and remove all codepoints outside of range for UTF-8
  def handle_call({:put, %RawMessage{raw: blob} = msg}, _, %{messages: m} = s) do
    {action, state} = if String.valid?(blob) do 
                        {:ok, Map.put(s, :messages, [msg | m])}
                      else
                        {:invalid_encoding, s}
                      end

    {:reply, action, state}
  end

  def handle_call(_, _, s), do: {:reply, :unsupported, s}

  ##############################################################################
  # Utility functions
  ##############################################################################

  def populate_queue(%{archive_name: name}) do
    # Download
    System.cmd("wget", ["-O", "#{tmp_dir()}/#{name}", "#{@base_url}/#{name}"])

    # Unarchive
    uuid = UUID.uuid4()
    dest_dir = "#{tmp_dir()}/#{uuid}"
    File.mkdir_p(dest_dir)
    System.cmd("tar", ["xvfj", "#{tmp_dir()}/#{name}", "-C", dest_dir])

    # self() returns the current PID: inside a task this means the 
    # task thread explicitly -- we want the current service PID instead
    svc_pid = self()

    # Parallel map into queues
    Path.wildcard("#{tmp_dir()}/#{uuid}/**/*")
      |> Enum.filter(&(File.regular?(&1) && !Regex.match?(~r/cmds$/, &1)))
      |> Enum.each(fn f ->
           Task.start(fn ->
             GenServer.call(svc_pid, {:put, RawMessage.new(raw: File.read!(f))})
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