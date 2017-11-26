defmodule PursuitServices.Util.REST.Google do
  alias PursuitServices.DB

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://www.googleapis.com"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Retry, delay: 500, max_retries: 5

  @spec refresh_token(DB.ThirdPartyAuthorizations) :: map
  def refresh_token(third_party_authorization) do
    params = %{
      client_id: Dotenv.get("GOOGLE_CLIENT_ID"),
      client_secret: Dotenv.get("GOOGLE_CLIENT_SECRET"),
      grant_type: "refresh_token",
      refresh_token: third_party_authorization.blob["refresh_token"]
    }

    post("/oauth2/v4/token", params)
  end
end