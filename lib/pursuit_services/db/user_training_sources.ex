defmodule PursuitServices.DB.UserTrainingSources do
  use Ecto.Schema

  @primary_key {:id, :integer, []}
  schema "user_training_sources" do
    field :auth_provider, :integer
    field :email, :string
    field :label, :string

  end
end
