defmodule Tiki.FormsFixtures do
  def form_fixture(attrs \\ %{}) do
    {:ok, form} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name"
      })
      |> Tiki.Forms.create_form()

    form
  end
end
