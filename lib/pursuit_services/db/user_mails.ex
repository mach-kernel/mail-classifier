defmodule PursuitServices.DB.UserMails do
  use Ecto.Schema

  @primary_key {:id, :integer, []}
  schema "user_mails" do
    field :auth_provider, :integer
    field :external_id, :string
    field :from, :string
    field :subject, :string
    field :body, :string
    field :created_at, :naive_datetime
    field :updated_at, :naive_datetime
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

    belongs_to :user, PursuitServices.DB.Users
    belongs_to :user_mail_thread, PursuitServices.DB.UserMailThreads
  end
end
