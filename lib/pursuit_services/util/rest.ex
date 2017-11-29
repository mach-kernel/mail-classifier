defmodule PursuitServices.Util.REST do
  require Logger

  def invoke(f, _ \\ nil, retry \\ 1)

  def invoke(_, l, retry) when retry > 3, do: {:error, l}

  def invoke(f, _, retry) do
    {_, response} = f.()
    
    case response do 
      %HTTPoison.Response{status_code: code} -> 
        if code < 400 do 
          {:ok, Poison.decode!(response.body)}
        else
          Logger.warn("The last HTTP call was responded to with #{code}")
          invoke(f, response.body, retry + 1)
        end

      %HTTPoison.Error{reason: why} -> 
        Logger.error("The last HTTP call failed because of #{why}")
        invoke(f, response.body, retry + 1)
    end
  end

  def default_headers(access_token), do: %{
    Authorization: "Bearer #{access_token}"
  }
end