defmodule PursuitServices.DB.Users do
  use Ecto.Schema

  @primary_key {:id, :integer, []}
  schema "users" do
    field :email, :string
    field :encrypted_password, :string
    field :reset_password_token, :string
    field :reset_password_sent_at, :naive_datetime
    field :remember_created_at, :naive_datetime
    field :sign_in_count, :integer
    field :current_sign_in_at, :naive_datetime
    field :last_sign_in_at, :naive_datetime
    field :created_at, :naive_datetime
    field :updated_at, :naive_datetime
    field :first_name, :string
    field :last_name, :string
    field :auth_provider, :integer

  end
end
