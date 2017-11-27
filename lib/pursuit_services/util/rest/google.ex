defmodule PursuitServices.Util.REST.Google do
  alias PursuitServices.DB
  alias PursuitServices.Util.REST

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

    REST.invoke(fn -> post("/oauth2/v4/token", params) end)
  end

  def message(access_token, id, params \\ %{}) do
    REST.invoke(fn -> get(
      "/gmail/v1/users/me/messages/#{id}",
      query: params,
      headers: %{Authorization: "Bearer #{access_token}"}
    ) end)
  end

  defp messages_list_all(_, _, messages, nil), do: {:ok, messages}

  defp messages_list_all(access_token, params, messages, page_token) when is_bitstring(page_token) do
    case messages_list(access_token, 
                       Map.merge(params, %{pageToken: page_token})) do
      {:ok, body} ->
        messages_list_all(
          access_token,
          params,
          messages ++ Map.get(body, "messages", []),
          body["nextPageToken"]
        )
      {:error, _} -> {:error, "Could not fetch messages"}
    end
  end

  def messages_list_all(access_token, params \\ %{}) do
    case messages_list(access_token, params) do
      {:ok, body} -> 
        messages_list_all(
          access_token,
          params,
          body["messages"],
          body["nextPageToken"]
        )
      {:error, _} -> {:error, "Could not fetch messages"}
    end
  end

  def messages_list(access_token, params \\ %{}) do
    REST.invoke(fn -> get(
      "/gmail/v1/users/me/messages",
      query: params,
      headers: %{Authorization: "Bearer #{access_token}"}
    ) end)
  end
end