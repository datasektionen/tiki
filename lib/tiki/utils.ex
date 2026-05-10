defmodule Tiki.Utils do
  @moduledoc """
  General helpers.
  """

  @doc """
  Cast a map to a struct. Assumes that the module defines an Ecto schema.
  """
  @spec cast_to_struct(module(), map()) :: struct()
  def cast_to_struct(module, params) when is_atom(module) and is_map(params) do
    struct(module) |> do_cast(params) |> Ecto.Changeset.apply_changes()
  end

  defp do_cast(%module{} = s, params) do
    fields = module.__schema__(:fields) -- module.__schema__(:embeds)

    Ecto.Changeset.cast(s, params, fields)
    |> then(fn cs ->
      Enum.reduce(module.__schema__(:embeds), cs, fn embed, acc ->
        Ecto.Changeset.cast_embed(acc, embed, with: &do_cast/2)
      end)
    end)
  end
end
