defmodule PursuitServices.DB.ClassifierCorpus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, []}
  schema "classifier_corpuses" do
    field :object, :binary
    field :created_at, :naive_datetime
    field :updated_at, :naive_datetime
    field :classifier_type, :string
    field :data_id, :string, default: ""
  end

  def changeset(tpa, params \\ %{}) do
    tpa
      |> cast(params, ~w(object created_at updated_at classifier_type data_id))
  end
end
