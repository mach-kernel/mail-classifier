defmodule PursuitServices.Util.REST.Google do
  alias PursuitServices.DB

  @base_url "https://www.googleapis.com"
  use PursuitServices.Util.REST

  @doc """
    Obtain a refresh token when provided with a ThirdPartyAuthorization shape.
    Updates the TPA record and returns a valid token set.
  """
  @spec refresh_token(DB.ThirdPartyAuthorization) :: map
  def refresh_token(third_party_authorization) do
    params = %{
      client_id: Dotenv.get("GOOGLE_CLIENT_ID"),
      client_secret: Dotenv.get("GOOGLE_CLIENT_SECRET"),
      grant_type: "refresh_token",
      refresh_token: third_party_authorization.blob["refresh_token"]
    } |> URI.encode_query

    invoke(fn -> HTTPotion.post(
      "#{__MODULE__.base_url}/oauth2/v4/token", 
      body: params,
      headers: 
        ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]
    ) end)
  end

  @spec messages_list_all(binary, map, list(map)) :: {atom, list(map)}
  def messages_list_all(token, params \\ %{}, messages \\ [])

  def messages_list_all(_, %{pageToken: :stop}, m), do: {:ok, m}

  @doc """
    List all messages across all pages of the requested query.
  """
  def messages_list_all(token, params, messages) do
    case messages_list(token, params) do
      {:ok, body} ->
        messages_list_all(
          token,
          Map.merge(params, %{pageToken: Map.get(body, "nextPageToken", :stop)}),
          messages ++ Map.get(body, "messages", [])
        )
      {:error, e} -> {:error, "API Error: #{e}"}
    end
  end

  @doc """
    Retrieve one message
  """
  @spec message(binary, any, map) :: {:ok, map} | {:error, any}
  def message(access_token, id, params \\ %{}) do
    invoke(fn -> 
      HTTPotion.get(
      "#{__MODULE__.base_url}/gmail/v1/users/me/messages/#{id}",
      [ query: params, headers: default_headers(access_token) ] ++ default_options
    ) end)
  end

  @doc """
    Retrieve a paginated list of messages from the API. Invoke this method again
    with parameter `nextPageToken` set in order to traverse pages.
  """
  @spec messages_list(binary, map) :: {atom, map}
  def messages_list(access_token, params \\ %{}) do
    invoke(fn -> HTTPotion.get(
      "#{__MODULE__.base_url}/gmail/v1/users/me/messages",
      [ query: params, headers: default_headers(access_token) ] ++ default_options
    ) end)
  end

  @doc "Retrieve a list of labels"
  @spec labels_list(binary, map) :: {atom, map}
  def labels_list(access_token, params \\ %{}) do
    invoke(fn -> HTTPotion.get(
      "#{__MODULE__.base_url}/gmail/v1/users/me/labels",
      [ query: params, headers: default_headers(access_token) ] ++ default_options
    ) end)
  end
end