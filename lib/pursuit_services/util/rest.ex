defmodule PursuitServices.Util.REST do
  def invoke(f) do
    response = f.()
    result = if response.status < 400, do: :ok, else: :error
    {result, response.body}
  end
end