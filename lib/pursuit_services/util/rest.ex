defmodule PursuitServices.Util.REST do
  require Logger

  defmacro __using__(_) do
    quote do
      import PursuitServices.Util.REST
      def base_url, do: @base_url
    end
  end

  def invoke(f, _ \\ nil, retry \\ 1)

  def invoke(_, l, retry) when retry > 4, do: {:error, l}

  def invoke(f, _, retry) do
    case response = f.() do 
      %HTTPotion.Response{status_code: code} -> 
        if code < 400 do 
          {:ok, Poison.decode!(response.body)}
        else
          # http://erlang.org/doc/man/rand.html#uniform-0
          :timer.sleep(round(15000 * retry * :rand.uniform))
          invoke(f, response.body, retry + 1)
        end

      %HTTPotion.ErrorResponse{message: why} -> 
        :timer.sleep(round(15000 * retry * :rand.uniform))
        invoke(f, response, retry + 1)
    end
  end

  def default_headers(access_token), do: [
    "Authorization": "Bearer #{access_token}"
  ]

  def default_options, do: [ ibrowse: [max_sessions: 100, max_pipeline_size: 10] ]
end