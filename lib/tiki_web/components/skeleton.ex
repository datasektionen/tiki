defmodule TikiWeb.Component.Skeleton do
  @moduledoc false
  use TikiWeb.Component

  @doc """
  Render skeleton
  """
  attr :class, :string, default: nil
  attr :rest, :global

  def skeleton(assigns) do
    ~H"""
    <div class={classes(["bg-muted animate-pulse rounded-md", @class])} {@rest}></div>
    """
  end
end
