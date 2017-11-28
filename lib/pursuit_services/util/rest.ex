defmodule PursuitServices.Util.REST do
  require Logger

  def invoke(f, _ \\ nil, retry \\ 1)

  def invoke(_, l, retry) when retry > 3, do: {:error, l}

  def invoke(f, _, retry) do
    response = f.()

    if response.status < 400 do 
      {:ok, response.body}
    else
      Logger.warn("The last API call failed with status: #{response.status}")
      :timer.sleep(1000 * retry)
      invoke(f, response.body, retry + 1)
    end
  end

  def default_headers(access_token), do: %{
    Authorization: "Bearer #{access_token}"
  }
end