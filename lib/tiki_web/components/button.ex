defmodule TikiWeb.Component.Button do
  @moduledoc false
  use TikiWeb.Component

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline ghost link),
    default: "default",
    doc: "the button variant style"

  attr :size, :string, values: ~w(default sm lg icon), default: "default"
  attr :rest, :global, include: ~w(disabled form name value)
  attr :navigate, :any, default: nil

  slot :inner_block, required: true

  def button(%{navigate: to} = assigns) when not is_nil(to) do
    ~H"""
    <.link navigate={@navigate} class={@class}>
      <.button type={@type} variant={@variant} size={@size} {@rest}>
        {render_slot(@inner_block)}
      </.button>
    </.link>
    """
  end

  def button(assigns) do
    assigns = assign(assigns, :variant_class, variant(assigns))

    ~H"""
    <button
      type={@type}
      class={
        classes([
          "inline-flex cursor-pointer items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:ring-ring focus-visible:outline-hidden focus-visible:ring-1 disabled:pointer-events-none disabled:opacity-50",
          @variant_class,
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @variants %{
    variant: %{
      "default" => "bg-primary text-primary-foreground shadow-sm hover:bg-primary/90",
      "destructive" =>
        "bg-destructive text-destructive-foreground shadow-xs hover:bg-destructive/90",
      "outline" =>
        "border border-input bg-background shadow-xs hover:bg-accent hover:text-accent-foreground",
      "secondary" => "bg-secondary text-secondary-foreground shadow-xs hover:bg-secondary/80",
      "ghost" => "hover:bg-accent hover:text-accent-foreground",
      "link" => "text-primary underline-offset-4 hover:underline"
    },
    size: %{
      "default" => "h-9 px-4 py-2",
      "sm" => "h-8 rounded-md px-3 text-xs",
      "lg" => "h-10 rounded-md px-8",
      "icon" => "h-9 w-9"
    }
  }

  @default_variants %{
    variant: "default",
    size: "default"
  }

  defp variant(props) do
    variants = Map.take(props, ~w(variant size)a)
    variants = Map.merge(@default_variants, variants)

    Enum.map_join(variants, " ", fn {key, value} -> @variants[key][value] end)
  end
end
