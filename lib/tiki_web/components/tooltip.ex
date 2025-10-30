defmodule TikiWeb.Component.Tooltip do
  @moduledoc false
  use TikiWeb.Component

  alias Phoenix.LiveView.JS

  @doc """
  Render a tooltip

  ## Examples:

  <.tooltip>
    <.button variant="outline">Hover me</.button>
    <.tooltip_content class="bg-primary text-white" theme={nil}>
     <p>Hi! I'm a tooltip.</p>
    </.tooltip_content>
  </.tooltip>

  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div
      class={classes(["group/tooltip relative inline-block", @class])}
      {@rest}
      phx-click={toggle_tooltip()}
      phx-click-away={hide_tooltip()}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Render only for compatible with shad ui
  """
  slot :inner_block, required: true
  attr :rest, :global

  def tooltip_trigger(assigns) do
    ~H"""
    <div {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Render tooltip content with smart positioning to avoid overflow.

  ## Attributes:
  - `side` - Preferred side: "top" | "bottom" | "left" | "right" (default: "top")

  The tooltip will intelligently position itself. For best results on mobile,
  prefer "bottom" or "top" which have more horizontal space.

  ## Examples:
    <.tooltip_content side="bottom">
      <p>Smart positioned content</p>
    </.tooltip_content>
  """
  attr :id, :string, required: true
  attr :class, :string, default: nil
  attr :side, :string, default: "top", values: ~w(bottom left right top)
  attr :rest, :global
  slot :inner_block, required: true

  def tooltip_content(assigns) do
    assigns =
      assign(assigns, :variant_class, side_variant(assigns.side))

    ~H"""
    <div
      id={"tooltip-#{@id}"}
      data-side={@side}
      data-tooltip-state="closed"
      class={
        classes([
          "z-50 absolute",
          "bg-popover text-popover-foreground rounded-md border px-3 py-1.5 text-sm shadow-md",
          "animate-in fade-in-0 zoom-in-95",
          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",
          "hidden data-[tooltip-state=open]:block group-hover/tooltip:block",
          "data-[tooltip-state=open]:pointer-events-auto group-hover/tooltip:pointer-events-auto",
          "max-w-xs break-words pointer-events-none",
          @variant_class,
          @class
        ])
      }
      {@rest}
      phx-hook=".TooltipPosition"
    >
      {render_slot(@inner_block)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".TooltipPosition">
      export default {
        mounted() {
          // Watch for click state changes
          this.observer = new MutationObserver((mutations) => {
            if (mutations.some(m => m.attributeName === 'data-tooltip-state')) {
              requestAnimationFrame(() => this.adjustForOverflow());
            }
          });
          this.observer.observe(this.el, { attributes: true, attributeFilter: ['data-tooltip-state'] });

          // Also watch for hover by listening to parent's mouseenter
          this.parent = this.el.closest('.group\\/tooltip');
          if (this.parent) {
            this.parent.addEventListener('mouseenter', () => {
              requestAnimationFrame(() => this.adjustForOverflow());
            });
          }
        },

        destroyed() {
          if (this.observer) this.observer.disconnect();
        },

        adjustForOverflow() {
          const margin = 18;

          // First, reset to default position to get accurate measurements
          this.el.style.left = '';

          // Get measurements with default position
          const rect = this.el.getBoundingClientRect();

          // Only adjust if tooltip is actually visible
          if (rect.width === 0 || rect.height === 0) {
            return;
          }

          // Now check if it overflows and adjust
          if (rect.right > window.innerWidth - margin) {
            const overflow = rect.right - (window.innerWidth - margin);
            this.el.style.left = `calc(50% - ${overflow}px)`;
          }
        }
      }
    </script>
    """
  end

  defp toggle_tooltip(js \\ %JS{}) do
    JS.toggle_attribute(js, {"data-tooltip-state", "open", "closed"},
      to: {:inner, "[data-tooltip-state]"}
    )
  end

  defp hide_tooltip(js \\ %JS{}) do
    JS.set_attribute(js, {"data-tooltip-state", "closed"}, to: {:inner, "[data-tooltip-state]"})
  end
end
