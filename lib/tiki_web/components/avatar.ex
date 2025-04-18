defmodule TikiWeb.Component.Avatar do
  @moduledoc false
  use TikiWeb.Component

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: false

  def avatar(assigns) do
    ~H"""
    <span
      class={classes(["relative h-10 w-10 shrink-0 overflow-hidden rounded-full", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(alt src)

  def avatar_image(assigns) do
    ~H"""
    <img
      class={classes(["aspect-square h-full w-full", @class])}
      {@rest}
      phx-update="ignore"
      style="display:none"
      onload="this.style.display=''"
    />
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: false

  def avatar_fallback(assigns) do
    ~H"""
    <span
      class={
        classes(["bg-muted flex h-full w-full items-center justify-center rounded-full", @class])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end
end
