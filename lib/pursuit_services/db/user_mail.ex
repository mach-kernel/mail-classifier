defmodule PursuitServices.DB.UserMail do
  use Ecto.Schema

  @primary_key {:id, :integer, []}
  schema "user_mails" do
    field :auth_provider, :integer
    field :external_id, :string
    field :from, :string
    field :subject, :string
    field :body, :string
    field :sent, :naive_datetime
    field :sentiment, :integer
    field :to, :string
    field :job_score, :float
    field :summary, :string
    field :topics, :string
    field :from_name, :string
    field :deliver_at, :naive_datetime
    field :status, :integer
    field :clean_body, :string

    timestamps(inserted_at: :created_at)

    belongs_to :user, PursuitServices.DB.User
  end
end
