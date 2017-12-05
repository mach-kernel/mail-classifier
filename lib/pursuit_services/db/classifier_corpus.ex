defmodule PursuitServices.DB.ClassifierCorpus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, []}
  schema "classifier_corpuses" do
    field :object, :binary
    field :classifier_type, :string
    field :data_id, :string, default: ""

    timestamps(inserted_at: :created_at)
  end

  def changeset(tpa, params \\ %{}) do
    tpa
      |> cast(params, ~w(object created_at updated_at classifier_type data_id))
  end
end
