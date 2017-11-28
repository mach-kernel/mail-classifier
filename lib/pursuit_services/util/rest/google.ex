defmodule PursuitServices.Util.REST.Google do
  alias PursuitServices.DB
  import PursuitServices.Util.REST

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://www.googleapis.com"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Retry, delay: 500, max_retries: 5

  @spec refresh_token(DB.ThirdPartyAuthorization) :: map
  def refresh_token(third_party_authorization) do
    params = %{
      client_id: Dotenv.get("GOOGLE_CLIENT_ID"),
      client_secret: Dotenv.get("GOOGLE_CLIENT_SECRET"),
      grant_type: "refresh_token",
      refresh_token: third_party_authorization.blob["refresh_token"]
    }

    invoke(fn -> post("/oauth2/v4/token", params) end)
  end

  @spec messages_list_all(bitstring, map, list(map)) :: {atom, list(map)}
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

  @spec message(bitstring, any, map) :: {:ok, map} | {:error, any}
  def message(access_token, id, params \\ %{}) do
    invoke(fn -> get(
      "/gmail/v1/users/me/messages/#{id}",
      query: params,
      headers: default_headers(access_token)
    ) end)
  end

  def messages_list(access_token, params \\ %{}) do
    invoke(fn -> get(
      "/gmail/v1/users/me/messages",
      query: params,
      headers: default_headers(access_token)
    ) end)
  end
end