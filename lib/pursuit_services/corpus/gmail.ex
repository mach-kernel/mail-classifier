defmodule PursuitServices.Corpus.Gmail do
  use GenServer

  def start(email_address, messages \\ []) do 
    GenServer.start_link(__MODULE__, messages)
  end
end