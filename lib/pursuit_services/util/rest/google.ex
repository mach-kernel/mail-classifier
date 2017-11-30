defmodule PursuitServices.Util.REST.Google do
  alias PursuitServices.DB

  @base_url "https://www.googleapis.com"
  use PursuitServices.Util.REST

  # Confirmed broken, error is "Invalid grant type: "
  # (yes, invalid grant type empty fucking string)
  @spec refresh_token(DB.ThirdPartyAuthorization) :: map
  def refresh_token(third_party_authorization) do
    params = %{
      client_id: Dotenv.get("GOOGLE_CLIENT_ID"),
      client_secret: Dotenv.get("GOOGLE_CLIENT_SECRET"),
      grant_type: "refresh_token",
      refresh_token: third_party_authorization.blob["refresh_token"]
    } |> Poison.encode!

    invoke(fn -> HTTPotion.post("#{__MODULE__.base_url}/oauth2/v4/token", params) end)
  end

  @spec messages_list_all(binary, map, list(map)) :: {atom, list(map)}
  def messages_list_all(token, params \\ %{}, messages \\ [])

  def messages_list_all(_, %{pageToken: :stop}, m), do: {:ok, m}

  def messages_list_all(token, params, messages) do
    case messages_list(token, params) do
      {:ok, body} ->
        messages_list_all(
          token,
          Map.merge(params, %{pageToken: Map.get(body, "nextPageToken", :stop)}),
          messages ++ Map.get(body, "messages", [])
        )
      {:error, _} -> {:error, "Could not fetch messages"}
    end
  end

  @spec message(binary, any, map) :: {:ok, map} | {:error, any}
  def message(access_token, id, params \\ %{}) do
    invoke(fn -> 
      HTTPotion.get(
      "#{__MODULE__.base_url}/gmail/v1/users/me/messages/#{id}",
      [ query: params, headers: default_headers(access_token) ] ++ default_options
    ) end)
  end

  def messages_list(access_token, params \\ %{}) do
    invoke(fn -> HTTPotion.get(
      "#{__MODULE__.base_url}/gmail/v1/users/me/messages",
      [ query: params, headers: default_headers(access_token) ] ++ default_options
    ) end)
  end
end