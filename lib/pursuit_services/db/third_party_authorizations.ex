defmodule PursuitServices.DB.ThirdPartyAuthorizations do
  use Ecto.Schema

  @primary_key {:id, :integer, []}
  schema "third_party_authorizations" do
    field :auth_provider, :integer
    field :created_at, :naive_datetime
    field :updated_at, :naive_datetime

    belongs_to :user, PursuitServices.DB.Users
  end
end
