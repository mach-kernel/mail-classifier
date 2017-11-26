defmodule PursuitServices.DB.ThirdPartyAuthorization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, []}
  schema "third_party_authorizations" do
    field :auth_provider, :integer
    field :created_at, :naive_datetime
    field :updated_at, :naive_datetime
    field :blob, :map

    belongs_to :user, PursuitServices.DB.User
  end

  def changeset(tpa, params \\ %{}) do
    tpa
      |> cast(params, ~w(auth_provider created_at updated_at blob user_id))
  end
end
