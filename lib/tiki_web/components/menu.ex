defmodule TikiWeb.Component.Menu do
  @moduledoc """
  Implement menu components
  """
  use TikiWeb.Component

  @doc """
  Render menu


  ## Examples:


      <.menu>
        <.menu_label>Account</.menu_label>
        <.menu_separator />

        <.menu_group>
          <.menu_item>
              Profile
            <.menu_shortcut>⌘P</.menu_shortcut>
          </.menu_item>

          <.menu_item>
              Billing
            <.menu_shortcut>⌘B</.menu_shortcut>
          </.menu_item>

          <.menu_item>
              Settings
            <.menu_shortcut>⌘S</.menu_shortcut>
          </.menu_item>
        </.menu_group>
      </.menu>
  """

  attr :class, :string, default: "top-0 left-full"
  slot :inner_block, required: true
  attr :rest, :global

  def menu(assigns) do
    ~H"""
    <div
      class={[
        "min-w-[8rem] bg-popover text-popover-foreground overflow-hidden rounded-md border p-1 shadow-md",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global

  def menu_item(assigns) do
    ~H"""
    <div
      class={
        classes([
          "hover:bg-accent",
          "rounded-xs relative flex cursor-default select-none items-center px-2 py-1.5 text-sm outline-hidden transition-colors data-disabled:pointer-events-none data-disabled:opacity-50 focus:bg-accent focus:text-accent-foreground",
          @class
        ])
      }
      {%{"data-disabled" => @disabled}}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :inset, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global

  def menu_label(assigns) do
    ~H"""
    <div class={classes(["px-2 py-1.5 text-sm font-semibold", @inset && "pl-8", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block

  def menu_separator(assigns) do
    ~H"""
    <div role="separator" class={classes(["bg-muted -mx-1 my-1 h-px", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def menu_shortcut(assigns) do
    ~H"""
    <span class={classes(["ml-auto text-xs tracking-widest opacity-60", @class])} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def menu_group(assigns) do
    ~H"""
    <div class={classes([@class])} role="group" {@rest}>{render_slot(@inner_block)}</div>
    """
  end
end
