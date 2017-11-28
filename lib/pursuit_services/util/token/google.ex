defmodule PursuitServices.Util.Token.Google do
  alias PursuitServices.DB
  alias PursuitServices.Util.Token
  alias PursuitServices.Util.REST.Google

  require Ecto.Query
  require Ecto.Changeset

  @behaviour Token
  import Token

  @impl true
  def get(user) do
    latest_auth = latest_authorization(user)
    current_time = System.system_time(:second)

    latest_auth = if latest_auth.blob["expires_at"] <= current_time do
      case Google.refresh_token(latest_auth) do 
        {:ok, body} ->
          changes = DB.ThirdPartyAuthorization.changeset(
            latest_auth, %{blob: body}
          )

          DB.update(changes)
          
        {:error, _} -> nil
      end
    else 
      latest_auth
    end

    if latest_auth, do: {:ok, latest_auth.blob}, else: {:error, "Can't refresh"}
  end
end