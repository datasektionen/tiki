defmodule TikiWeb.Component.Dialog do
  @moduledoc """
  Implement of Dialog components from https://ui.shadcn.com/docs/components/dialog
  """
  use TikiWeb.Component

  @doc """
  Dialog component

  ## Examples:

        <.dialog :if={@live_action in [:new, :edit]} id="pro-dialog" show on_cancel={JS.navigate(~p"/p")}>
          <.dialog_content class="sm:max-w-[425px]">
            <.dialog_header>
              <.dialog_title>Edit profile</.dialog_title>
              <.dialog_description>
                Make changes to your profile here click save when you're done
              </.dialog_description>
            </.dialog_header>
              <div class_name="grid gap-4 py-4">
                <div class_name="grid grid-cols_4 items-center gap-4">
                  <.label for="name" class-name="text-right">
                    name
                  </.label>
                  <input id="name" value="pedro duarte" class-name="col-span-3" />
                </div>
                <div class="grid grid-cols-4 items_center gap-4">
                  <.label for="username" class="text-right">
                    username
                  </.label>
                  <input id="username" value="@peduarte" class="col-span-3" />
                </div>
              </div>
              <.dialog_footer>
                <.button type="submit">save changes</.button>
              </.dialog_footer>
              </.dialog_content>
        </.dialog>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :class, :string, default: nil

  attr :safe, :boolean,
    default: false,
    doc: "If true, the dialog will not close when clicking outside of it"

  slot :inner_block, required: true

  def dialog(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="group/dialog relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-black/80 fixed inset-0 transition-opacity group-data-[state=closed]/dialog:animate-out group-data-[state=closed]/dialog:fade-out-0 group-data-[state=open]/dialog:animate-in group-data-[state=open]/dialog:fade-in-0"
        aria-hidden="true"
      />
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true" tabindex="0">
        <div class="flex min-h-full items-center justify-center py-4">
          <.focus_wrap
            id={"#{@id}-wrap"}
            phx-window-keydown={if !@safe, do: JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={if !@safe, do: JS.exec("data-cancel", to: "##{@id}")}
            class="relative w-full sm:max-w-xl"
          >
            <div class={
              classes([
                "bg-background z-50 grid w-full max-w-xl gap-4 border p-6 shadow-lg duration-200 group-data-[state=closed]/dialog:animate-out group-data-[state=closed]/dialog:fade-out-0 group-data-[state=closed]/dialog:zoom-out-95 group-data-[state=open]/dialog:animate-in group-data-[state=open]/dialog:fade-in-0 group-data-[state=open]/dialog:zoom-in-95 sm:rounded-lg",
                @class
              ])
            }>
              {render_slot(@inner_block)}

              <.close_button id={@id} safe={@safe} />
            </div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  defp close_button(%{safe: true} = assigns) do
    ~H"""
    <button
      type="button"
      class="rounded-xs ring-offset-background absolute top-4 right-4 opacity-70 transition-opacity group-data-[state=open]/dialog:bg-accent group-data-[state=open]/dialog:text-muted-foreground hover:opacity-100 focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:pointer-events-none"
      phx-click={JS.exec("data-cancel", to: "##{@id}")}
      data-confirm={gettext("Are you sure?")}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="h-5 w-5"
      >
        <path d="M18 6 6 18"></path>
        <path d="m6 6 12 12"></path>
      </svg>
      <span class="sr-only">Close</span>
    </button>
    """
  end

  defp close_button(assigns) do
    ~H"""
    <button
      type="button"
      class="rounded-xs ring-offset-background absolute top-4 right-4 opacity-70 transition-opacity group-data-[state=open]/dialog:bg-accent group-data-[state=open]/dialog:text-muted-foreground hover:opacity-100 focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:pointer-events-none"
      phx-click={JS.exec("data-cancel", to: "##{@id}")}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="h-5 w-5"
      >
        <path d="M18 6 6 18"></path>
        <path d="m6 6 12 12"></path>
      </svg>
      <span class="sr-only">Close</span>
    </button>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_header(assigns) do
    ~H"""
    <div class={classes(["flex flex-col space-y-1.5 text-center sm:text-left", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_title(assigns) do
    ~H"""
    <h3 class={classes(["text-lg font-semibold leading-none tracking-tight", @class])}>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_description(assigns) do
    ~H"""
    <p class={classes(["text-muted-foreground text-sm", @class])}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_footer(assigns) do
    ~H"""
    <div class={classes(["flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.set_attribute({"data-state", "open"}, to: "##{id}")
    |> JS.show(to: "##{id}", transition: {"_", "_", "_"}, time: 150)
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.set_attribute({"data-state", "closed"}, to: "##{id}")
    |> JS.hide(to: "##{id}", transition: {"_", "_", "_"}, time: 150)
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
