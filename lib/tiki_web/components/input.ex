defmodule TikiWeb.Component.Input do
  @moduledoc false
  use TikiWeb.Component

  import TikiWeb.Component.Label
  import TikiWeb.CoreComponents, only: [error: 1, icon: 1]

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :default, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :description, :string, default: nil, doc: "the help description for the input"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step class)

  slot :checkbox_label, required: false

  def input(%{field: %Phoenix.HTML.FormField{}} = assigns) do
    prepare_assign(assigns)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={@rest[:class]}>
      <label class="flex items-center gap-4 text-sm">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="border-primary text-primary bg-background size-4 rounded-sm shadow-sm checked:bg-primary focus:ring-0 dark:checked:bg-dark-checkmark dark:checked:text-primary"
          {@rest}
        />
        <%= if @checkbox_label != [] do %>
          {render_slot(@checkbox_label)}
        <% else %>
          {@label}
        <% end %>
      </label>
      <p :if={@description != nil} class="text-muted-foreground mt-2 text-sm">{@description}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={@rest[:class]}>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class="border-input bg-background ring-offset-background mt-2 flex h-10 w-full rounded-md border py-2 pr-10 pl-3 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus:border-input focus:ring-offset-background focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :if={@description != nil} class="text-muted-foreground mt-2 text-sm">{@description}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={@rest[:class]}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          @errors == [] && "border-input",
          "min-h-[10rem] bg-background ring-offset-background mt-2 flex w-full rounded-md border px-3 py-2 text-sm placeholder:text-muted-foreground focus:ring-ring focus:ring-offset-background focus:border-input focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          @errors == [] && "border-input",
          @errors != [] && "border-destructive"
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@description != nil} class="text-muted-foreground mt-2 text-sm">{@description}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class={@rest[:class]}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={normalize_value(@type, @value)}
        class={[
          "bg-background ring-offset-background mt-2 flex h-10 w-full rounded-md border px-3 py-2 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus:ring-offset-background focus:border-input focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          @errors == [] && "border-input",
          @errors != [] && "border-destructive"
        ]}
        {@rest}
      />
      <p :if={@description != nil} class="text-muted-foreground mt-2 text-sm">{@description}</p>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  attr :id, :string
  attr :name, :string
  attr :rest, :global
  attr :prompt, :string, default: nil
  attr :options, :list, required: true
  attr :value, :any

  def simple_select(assigns) do
    ~H"""
    <select
      id={@id}
      name={@name}
      class="border-input bg-background ring-offset-background flex h-10 w-full rounded-md border py-2 pr-10 pl-3 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus:border-input focus:ring-offset-background focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
      {@rest}
    >
      <option :if={@prompt} value="">{@prompt}</option>
      {Phoenix.HTML.Form.options_for_select(@options, @value)}
    </select>
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step class)

  def leading_logo_input(assigns) do
    ~H"""
    <div class={@rest[:class]}>
      <div class="relative flex w-full">
        <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
          <.icon name="hero-magnifying-glass" class="text-muted-foreground h-5 w-5" />
        </div>
        <span class="w-full">
          <input
            type="text"
            name={@name}
            id={@id}
            value={@value}
            class="bg-background border-input ring-offset-background block h-10 w-full rounded-md border px-3 py-2 pl-10 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus:border-input focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            {@rest}
          />
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Provides a radio group input for a given form field.

  ## Examples

      <.radio_group field={@form[:tip]}>
        <:radio value="0">No Tip</:radio>
        <:radio value="10">10%</:radio>
        <:radio value="20">20%</:radio>
      </.radio_group>
  """
  attr :field, Phoenix.HTML.FormField, required: true

  slot :radio, required: true do
    attr :value, :string, required: true
    attr :class, :string
  end

  attr :rest, :global

  slot :inner_block

  def radio_group(%{field: %Phoenix.HTML.FormField{}} = assigns) do
    assigns = prepare_assign(assigns)

    ~H"""
    <div>
      <div class={@rest[:class]}>
        {render_slot(@inner_block)}
        <div
          :for={
            {%{value: value, class: class} = rad, idx} <-
              Enum.map(@radio, &Map.put_new(&1, :class, nil)) |> Enum.with_index()
          }
          class={class}
        >
          <label for={"#{@id}-#{idx}"}>{render_slot(rad)}</label>
          <input
            type="radio"
            name={@name}
            id={"#{@id}-#{idx}"}
            value={value}
            checked={to_string(@value) == to_string(value)}
            class="aspect-square border-primary text-foreground h-4 w-4 rounded-full border shadow-sm focus:ring-0 focus:ring-offset-0 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-background dark:checked:bg-dark-radio"
            }
          />
        </div>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  A generic form component that works with Changesets generated from Haj.Form.

  Question types are: :select, :multi_select, :text_area, :text, :email, :attendee_name
  """

  attr :question, :any, required: true
  attr :field, :any, required: true
  attr :class, :string, default: ""
  attr :default, :any

  def form_input(%{question: %{type: :select}} = assigns) do
    ~H"""
    <div class={@class}>
      <.input field={@field} type="select" options={@question.options} label={@question.name} />
    </div>
    """
  end

  def form_input(%{question: %{type: :multi_select}} = assigns) do
    ~H"""
    <div class={@class}>
      <label class="text-muted-foreground block text-sm font-semibold leading-6">
        {@question.name}
      </label>
      <div class="mt-2 flex flex-col gap-1">
        <div :for={option <- @question.options}>
          <.input
            name={"#{@field.name}[#{option}]"}
            type="checkbox"
            value={
              option in Ecto.Changeset.get_field(assigns.field.form.source, assigns.field.field, [])
            }
            label={option}
          />
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
    </div>
    """
  end

  def form_input(%{question: %{type: :text_area}} = assigns) do
    ~H"""
    <div class={@class}>
      <.input field={@field} type="textarea" label={@question.name} />
    </div>
    """
  end

  def form_input(%{question: %{type: :email}} = assigns) do
    ~H"""
    <div class={@class}>
      <.input field={@field} type="email" label={@question.name} default={@default} />
    </div>
    """
  end

  def form_input(assigns) do
    ~H"""
    <div class={@class}>
      <.input field={@field} type="text" label={@question.name} default={@default} />
    </div>
    """
  end

  defp normalize_value("datetime-local", %DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Europe/Stockholm")
    |> DateTime.to_string()
    |> to_form_datetime()
  end

  defp normalize_value("datetime-local", %NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.shift_zone!("Europe/Stockholm")
    |> DateTime.to_string()
    |> to_form_datetime()
  end

  defp normalize_value(type, value), do: Phoenix.HTML.Form.normalize_value(type, value)

  defp to_form_datetime(<<date::10-binary, ?\s, hour_minute::5-binary, _rest::binary>>) do
    {:safe, [date, ?T, hour_minute]}
  end
end
