defmodule PursuitServices.Util.Token do 
  @moduledoc """
  Token retrieval service behavior
  """

  alias PursuitServices.DB
  import Ecto.Query

  @callback get(DB.User) :: {:ok, map} | {:error, binary}

  def latest_authorization(user) do
    from(
      tpa in DB.ThirdPartyAuthorization,
      where: tpa.user_id == ^user.id,
      order_by: [asc: tpa.created_at]
    ) |> Ecto.Query.first
      |> DB.one
  end
end