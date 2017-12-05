defmodule PursuitServices.Util.Token.Google do
  alias PursuitServices.DB
  alias PursuitServices.Util.Token
  alias PursuitServices.Util.REST.Google

  import Ecto.Query
  require Ecto.Changeset

  @behaviour Token
  import Token

  @spec get_from_email(binary) :: binary
  def get_from_email(email) do
    case PursuitServices.Util.Token.Google.get(
      from(u in DB.User, where: u.email == ^email, limit: 1) |> DB.one
    ) do 
      {:ok, token} -> token["token"]
      _ -> nil
    end
  end

  @impl true
  def get(user) do
    latest_auth = latest_authorization(user)
    current_time = System.system_time(:second)

    latest_auth = if latest_auth.blob["expires_at"] <= current_time do
      case Google.refresh_token(latest_auth) do 
        {:ok, %{"expires_in" => expire_offset, "access_token" => token} = body} ->
          body = Map.merge(
            body,
            %{ "expires_at" => current_time + expire_offset, "token" => token }
          )

          changes = DB.ThirdPartyAuthorization.changeset(
            latest_auth, %{blob: Map.merge(latest_auth.blob, body)}
          )

          case DB.update(changes) do 
            {:ok, record} -> record
            {:error, _} -> nil
          end
          
        {:error, _} -> nil
      end
    else 
      latest_auth
    end

    if latest_auth, do: {:ok, latest_auth.blob}, else: {:error, "Can't refresh"}
  end
end