defmodule PursuitServices.Util.Token.Google do
  alias PursuitServices.Util.Token
  alias PursuitServices.Util.REST.Google

  require IEx
  require Ecto.Query
  require Ecto.Changeset

  @behaviour Token

  @impl true
  def token(user) do
    latest_auth = Token.latest_authorization(user)

    if latest_auth.blob["expires_at"] <= System.system_time(:second) do
      new_blob = Google.refresh_token(latest_auth)

      changeset = Ecto.Changeset
      latest_auth = DB.update(latest_auth, blob: new_blob)
    end

    {:ok, latest_auth.blob}
  end
end