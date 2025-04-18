defmodule TikiWeb.Component.Table do
  @moduledoc """
  Implement of table components from https://ui.shadcn.com/docs/components/table
  """
  use TikiWeb.Component

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"
  attr :class, :string, default: nil
  attr :rest, :global

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class={classes(["caption-bottom w-full text-sm", @class])} {@rest}>
      <.table_header>
        <.table_row>
          <.table_head :for={col <- @col}>
            {col[:label]}
          </.table_head>
          <.table_head :if={@action != []}><span class="sr-only">"Actions"</span></.table_head>
        </.table_row>
      </.table_header>
      <.table_body id={@id} phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}>
        <.table_row :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <.table_cell
            :for={{col, _i} <- Enum.with_index(@col)}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </.table_cell>
          <.table_cell
            :if={@action != []}
            class="relative space-x-1 whitespace-nowrap text-right font-medium"
          >
            <span
              :for={action <- @action}
              class="text-foreground relative leading-6 hover:text-muted-foreground"
            >
              {render_slot(action, @row_item.(row))}
            </span>
          </.table_cell>
        </.table_row>
      </.table_body>
    </table>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_header(assigns) do
    ~H"""
    <thead class={classes(["[&_tr]:border-b", @class])} {@rest}>
      {render_slot(@inner_block)}
    </thead>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_row(assigns) do
    ~H"""
    <tr
      class={
        classes([
          "border-b transition-colors data-[state=selected]:bg-muted hover:bg-muted/50",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </tr>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_head(assigns) do
    ~H"""
    <th
      class={
        classes([
          "text-muted-foreground [&:has([role=checkbox])]:pr-0 h-12 px-4 text-left align-middle font-medium",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </th>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_body(assigns) do
    ~H"""
    <tbody class={classes(["[&_tr:last-child]:border-0", @class])} {@rest}>
      {render_slot(@inner_block)}
    </tbody>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_cell(assigns) do
    ~H"""
    <td class={classes(["[&:has([role=checkbox])]:pr-0 p-4 align-middle", @class])} {@rest}>
      {render_slot(@inner_block)}
    </td>
    """
  end

  @doc """
  Render table footer
  """
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def table_footer(assigns) do
    ~H"""
    <div class={classes(["bg-muted/50 border-t font-medium last:[&>tr]:border-b-0", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_caption(assigns) do
    ~H"""
    <caption class={classes(["text-muted-foreground mt-4 text-sm", @class])} {@rest}>
      {render_slot(@inner_block)}
    </caption>
    """
  end
end
