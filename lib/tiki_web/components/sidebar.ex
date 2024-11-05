defmodule TikiWeb.Component.Sidebar do
  use TikiWeb, :html

  import TikiWeb.Component.DropdownMenu
  import TikiWeb.Component.Menu
  import TikiWeb.Component.Sheet
  import TikiWeb.Component.Breadcrumb

  alias Tiki.Policy
  alias Tiki.Events.Event

  attr :event, :map, default: nil
  attr :mobile, :boolean, default: false

  def sidebar(%{current_team: nil} = assigns) do
    ~H"""
    <nav class="flex flex-col gap-1 px-2 py-5">
      <.sidebar_header mobile={@mobile} current_team={@current_team} current_user={@current_user} />

      <div :if={Policy.authorize?(:tiki_admin, @current_user)} class="flex w-full flex-col py-4">
        <.admin_items active_tab={@active_tab} />
      </div>
    </nav>
    <!-- sidebar footer -->
    <.sidebar_footer mobile={@mobile} current_user={@current_user} />
    """
  end

  def sidebar(%{event: nil} = assigns) do
    ~H"""
    <nav class="flex flex-col gap-1 px-2 py-5">
      <.sidebar_header mobile={@mobile} current_team={@current_team} current_user={@current_user} />
      <div class="flex w-full flex-col py-4">
        <.all_event_items active_tab={@active_tab} />
      </div>
      <div :if={Policy.authorize?(:tiki_admin, @current_user)} class="flex w-full flex-col py-4">
        <.admin_items active_tab={@active_tab} />
      </div>
    </nav>
    <!-- sidebar footer -->
    <.sidebar_footer mobile={@mobile} current_user={@current_user} />
    """
  end

  def sidebar(%{event: %Event{id: nil}} = assigns) do
    assign(assigns, event: nil)
    |> sidebar()
  end

  def sidebar(assigns) do
    ~H"""
    <nav class="flex flex-col gap-1 px-2 py-5">
      <.sidebar_header mobile={@mobile} current_team={@current_team} current_user={@current_user} />
      <div class="flex w-full flex-col py-4">
        <.event_items active_tab={@active_tab} event={@event} />
      </div>
      <div class="flex w-full flex-col py-4">
        <.all_event_items active_tab={@active_tab} />
      </div>
      <div :if={Policy.authorize?(:tiki_admin, @current_user)} class="flex w-full flex-col py-4">
        <.admin_items active_tab={@active_tab} />
      </div>
    </nav>
    <!-- sidebar footer -->
    <.sidebar_footer mobile={@mobile} current_user={@current_user} />
    """
  end

  attr :active_tab, :atom
  attr :event, :map

  defp event_items(assigns) do
    ~H"""
    <.sidebar_label><%= gettext("Event") %></.sidebar_label>
    <.sidebar_item
      icon="hero-calendar-days"
      text={gettext("Overview")}
      to={~p"/admin/events/#{@event}"}
      active={@active_tab == :event_overview}
    />
    <.sidebar_group>
      <:header>
        <.icon name="hero-user-group" class="h-4 w-4" />
        <span><%= gettext("Registrations") %></span>
      </:header>
      <:item
        text={gettext("Attendees")}
        to={~p"/admin/events/#{@event}/attendees"}
        active={@active_tab == :event_attendees}
      />

      <:item
        text={gettext("Live status")}
        to={~p"/admin/events/#{@event}/status"}
        active={@active_tab == :live_status}
      />
    </.sidebar_group>

    <.sidebar_group>
      <:header>
        <.icon name="hero-ticket" class="h-4 w-4" />
        <span><%= gettext("Tickets") %></span>
      </:header>

      <:item
        text={gettext("Ticket types")}
        to={~p"/admin/events/#{@event}/tickets"}
        active={@active_tab == :event_tickets}
      />
    </.sidebar_group>

    <.sidebar_item
      icon="hero-document-text"
      text="Formulär"
      to={~p"/admin/events/#{@event}/forms"}
      active={@active_tab == :forms}
    />
    """
  end

  defp all_event_items(assigns) do
    ~H"""
    <.sidebar_label><%= gettext("General") %></.sidebar_label>
    <.sidebar_item
      icon="hero-home"
      text={gettext("Dashboard")}
      to={~p"/admin/"}
      active={@active_tab == :dashboard}
    />
    <.sidebar_group>
      <:header>
        <.icon name="hero-calendar-days" class="h-4 w-4" />
        <span><%= gettext("Event") %></span>
      </:header>
      <:item text={gettext("All events")} to={~p"/admin/events"} active={@active_tab == :all_events} />
      <:item
        text={gettext("New event")}
        to={~p"/admin/events/new"}
        active={@active_tab == :new_event}
      />
    </.sidebar_group>
    <.sidebar_group>
      <:header>
        <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
        <span><%= gettext("Settings") %></span>
      </:header>
      <:item text={gettext("Members")} to={~p"/team/members"} />
      <:item text={gettext("Payments")} to="" />
    </.sidebar_group>
    """
  end

  defp admin_items(assigns) do
    ~H"""
    <.sidebar_label><%= gettext("Admin") %></.sidebar_label>
    <.sidebar_group>
      <:header>
        <.icon name="hero-user-group" class="h-4 w-4" />
        <span><%= gettext("Teams") %></span>
      </:header>
      <:item text={gettext("All teams")} to={~p"/admin/teams"} active={@active_tab == :all_teams} />
      <:item text={gettext("New team")} to={~p"/admin/teams/new"} active={@active_tab == :new_team} />
    </.sidebar_group>
    """
  end

  def nav_header(assigns) do
    ~H"""
    <header class="bg-background flex h-auto items-center md:bg-transparent">
      <.sheet>
        <.sheet_trigger target="sidebar-sheet">
          <button class="flex flex-row items-center md:hidden">
            <.icon name="hero-bars-2" class="h-5 w-5" />
            <span class="sr-only">Toggle Menu</span>
          </button>
        </.sheet_trigger>
        <.sheet_content id="sidebar-sheet" side="left" class="w-72 p-0">
          <:custom_close_btn></:custom_close_btn>
          <div class="flex h-full flex-col">
            <%= sidebar(Map.put(assigns, :mobile, true)) %>
          </div>
        </.sheet_content>
      </.sheet>
      <span class="bg-foreground/40 w-[1px] mx-4 h-4 shrink-0 md:hidden" />
      <.breadcrumbs active_tab={@active_tab} breadcrumbs={@breadcrumbs} />
    </header>
    """
  end

  defp breadcrumbs(assigns) do
    assigns = assign(assigns, :len, Enum.count(assigns.breadcrumbs))

    ~H"""
    <div class="md:hidden">
      <.breadcrumb_list>
        <.breadcrumb_item class="text-sm">
          <.breadcrumb_page class="text-foreground">
            <% {name, _} = List.last(assigns.breadcrumbs) %>
            <%= name %>
          </.breadcrumb_page>
        </.breadcrumb_item>
      </.breadcrumb_list>
    </div>
    <.breadcrumb class="hidden md:flex">
      <.breadcrumb_list>
        <.breadcrumb_item :for={{{name, url}, index} <- Enum.with_index(@breadcrumbs)}>
          <.breadcrumb_link navigate={url} class={index == @len - 1 && "text-foreground"}>
            <%= name %>
          </.breadcrumb_link>
          <.breadcrumb_separator :if={index != @len - 1} />
        </.breadcrumb_item>
      </.breadcrumb_list>
    </.breadcrumb>
    """
  end

  defp sidebar_header(assigns) do
    ~H"""
    <.dropdown_menu>
      <.dropdown_menu_trigger>
        <button class="flex w-full flex-row items-center gap-2 rounded-md p-2 hover:bg-accent">
          <div class="bg-primary flex h-8 w-8 items-center justify-center rounded-lg">
            <.tiki_logo class="fill-primary-foreground h-5 w-5" />
          </div>
          <div :if={@current_team} class="grid flex-1 text-left text-sm leading-tight">
            <span class="truncate font-semibold"><%= @current_team.name %></span><span class="truncate text-xs">Team</span>
          </div>

          <div :if={!@current_team} class="grid flex-1 text-left text-sm leading-tight">
            <span class="truncate font-semibold"><%= gettext("No team") %></span><span class="truncate text-xs"><%= gettext("Create or join one") %></span>
          </div>
          <.icon name="hero-chevron-up-down" class="ml-auto h-5 w-5" />
        </button>
      </.dropdown_menu_trigger>
      <.dropdown_menu_content side={(@mobile && "bottom") || "right"}>
        <.menu class="w-[17rem] top-0 left-full z-40">
          <.menu_label>Teams</.menu_label>
          <.menu_separator />
          <.menu_group>
            <.form for={%{}} action={~p"/admin/set_team"} method="post">
              <button
                :for={{membership, index} <- @current_user.memberships |> Enum.with_index(1)}
                class="w-full"
                name="team_id"
                value={membership.team.id}
              >
                <.menu_item class="hover:cursor-pointer">
                  <span><%= membership.team.name %></span>
                  <.menu_shortcut>⌘<%= index %></.menu_shortcut>
                </.menu_item>
              </button>
            </.form>

            <.link navigate={~p"/admin/teams/new"}>
              <.menu_item class="hover:cursor-pointer">
                <.icon name="hero-plus" class="mr-2 h-4 w-4" />
                <span>New team</span>
                <.menu_shortcut>⌘N</.menu_shortcut>
              </.menu_item>
            </.link>
          </.menu_group>
        </.menu>
      </.dropdown_menu_content>
    </.dropdown_menu>
    """
  end

  defp sidebar_footer(assigns) do
    ~H"""
    <nav class="mt-auto flex flex-col gap-1 px-2 py-2">
      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <button class="flex w-full flex-row items-center gap-2 rounded-md p-2 hover:bg-accent">
            <img
              src="https://zfinger.datasektionen.se/user/asalamon/image/100"
              class="fill-primary-foreground h-8 w-8 rounded-lg object-cover"
            />
            <div class="grid flex-1 text-left text-sm leading-tight">
              <span class="truncate font-semibold"><%= @current_user.full_name %></span>
              <span class="truncate text-xs"><%= @current_user.email %></span>
            </div>
            <.icon name="hero-chevron-up-down" class="ml-auto h-5 w-5" />
          </button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content side={(@mobile && "top") || "right"} align="end">
          <.menu class="w-[17rem] top-0 left-full z-40">
            <.menu_label>
              <div class="inline-flex gap-2">
                <img
                  src="https://zfinger.datasektionen.se/user/asalamon/image/100"
                  class="fill-primary-foreground h-8 w-8 rounded-lg object-cover"
                />
                <div class="grid flex-1 text-left text-sm leading-tight">
                  <span class="truncate font-semibold"><%= @current_user.full_name %></span>
                  <span class="truncate text-xs font-normal"><%= @current_user.email %></span>
                </div>
              </div>
            </.menu_label>
            <.menu_separator />
            <.menu_group>
              <.link navigate={~p"/admin/user-settings"}>
                <.menu_item class="hover:cursor-pointer">
                  <.icon name="hero-cog-6-tooth" class="mr-2 h-4 w-4" />
                  <span><%= gettext("Settings") %></span>
                </.menu_item>
              </.link>
              <.menu_separator />

              <.link href={~p"/users/log_out"} method="delete">
                <.menu_item class="hover:cursor-pointer">
                  <.icon name="hero-arrow-left-end-on-rectangle" class="mr-2 h-4 w-4" />
                  <span><%= gettext("Log out") %></span>
                </.menu_item>
              </.link>
            </.menu_group>
          </.menu>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </nav>
    """
  end

  slot :inner_block, required: true
  slot :header, required: true
  attr :expanded, :boolean, default: false

  slot :item do
    attr :text, :string, required: true
    attr :active, :boolean
    attr :to, :string
  end

  defp sidebar_group(assigns) do
    assigns = assign(assigns, item: Enum.map(assigns.item, &Map.put_new(&1, :active, false)))

    ~H"""
    <div class="flex flex-col gap-1">
      <details name={nil} class="group peer" open={Enum.any?(@item, & &1.active)}>
        <summary class="cursor-pointer list-none">
          <div class="flex flex-row items-center gap-2 rounded-md p-2 text-sm hover:bg-accent">
            <%= render_slot(@header) %>
            <.icon
              name="hero-chevron-right-mini"
              class="mr-[2px] ml-auto h-4 w-4 transition-transform duration-300 group-open:rotate-90"
            />
          </div>
        </summary>
      </details>
      <div class="grid-rows-[0fr] transition-[grid-template-rows] grid duration-100 peer-open:grid-rows-[1fr]">
        <div class="overflow-hidden">
          <div class="flex flex-col gap-1 px-2 text-sm">
            <div class="ml-2 border-l">
              <%= for item <- @item do %>
                <div class={[
                  "border-l flex flex-col pl-2 -ml-[1px]",
                  item.active && "border-foreground"
                ]}>
                  <.sidebar_item text={item.text} to={item.to} active={item.active || nil} />
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :active, :boolean, default: false
  attr :icon, :string, default: nil
  attr :to, :any
  attr :text, :string

  defp sidebar_item(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "text-foreground inline-flex items-center gap-2 rounded-md p-2 hover:bg-accent",
        @active && "font-medium"
      ]}
    >
      <.icon :if={@icon} name={@icon} class="h-4 w-4" />
      <div class="text-sm"><%= @text %></div>
    </.link>
    """
  end

  defp sidebar_label(assigns) do
    ~H"""
    <div class="text-secondary-foreground p-2 text-xs font-medium">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :class, :string, default: ""

  defp tiki_logo(assigns) do
    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      width="314.896"
      height="305.649"
      viewBox="0 0 83.316 80.87"
    >
      <path
        d="M18.242 61.32c-1.763.008-3.509.38-5.191 1.428-3.365 2.098-4.606 6.204-4.668 11.24-.07 5.675 1.377 10.145 4.65 12.787 3.273 2.642 7.355 2.91 11.276 2.594 7.84-.63 16.697-3.639 23.884-3.652 7.218-.013 16.568 2.872 24.725 3.527 4.078.328 8.166.175 11.62-2.224 3.452-2.4 5.187-6.871 5.089-12.332-.096-5.322-1.509-9.577-4.957-11.768-3.449-2.191-7.273-1.718-11.016-.94-7.485 1.558-16.334 5.14-25.511 5.168-9.183.029-17.566-3.444-24.596-5.072-1.758-.407-3.541-.764-5.305-.756zm60.62 7.793c.884.018 1.443.153 1.679.303.472.3 1.314 1.259 1.389 5.41.072 4.012-.77 5.166-1.785 5.871-1.016.706-3.288 1.14-6.612.873-6.647-.534-16.262-3.567-25.353-3.55-9.121.016-18.367 3.185-24.489 3.677-3.06.247-4.925-.188-5.822-.912-.897-.724-1.843-2.283-1.789-6.703.048-3.917.82-4.66 1.045-4.8.226-.141 1.778-.379 4.684.294 5.81 1.346 15.279 5.306 26.359 5.272 11.086-.035 20.878-4.046 27.053-5.33 1.543-.322 2.755-.422 3.64-.405z"
        style="stroke-linejoin:bevel;-inkscape-stroke:none;paint-order:stroke fill markers"
        transform="translate(-7.272 -8.605)"
      />
      <g style="display:inline">
        <path
          d="M39.994 30.281c-2.585-.001-5.31.085-8.183.24v7.515c19.37-1.093 28.905.691 39.234 9.343l2.402 2.012 2.408-2.004c9.601-7.992 23.217-10.24 39.272-9.342v-7.517c-15.707-.827-30.291 1.202-41.625 9.323-8.219-6.132-17.016-8.893-28.59-9.454a102.776 102.776 0 0 0-4.918-.116zm71.056 9.839a74.37 74.37 0 0 0-2.902.033c-11.923.367-23.85 3.866-34.763 12.503-6.83-5.471-13.413-9.04-21.024-10.723-6.04-1.335-12.615-1.596-20.55-1.193v8.005c7.696-.401 13.695-.15 18.828.985 5.972 1.32 10.967 3.777 16.628 8.159a41.062 41.062 0 0 0-1.924 2.042c-8.032-6.072-15.518-8.248-24.556-8.501-2.816-.079-5.796.037-8.976.271v8.002c12.747-1.044 19.165-.613 28.017 6.035-1.801 1.723-3.726 3.353-5.758 4.637-3.344 2.113-6.809 3.308-10.88 2.877-3.202-.34-6.964-1.74-11.379-5.053v9.5c3.633 2.005 7.15 3.133 10.537 3.492 6.164.654 11.61-1.299 15.988-4.066s7.852-6.332 10.648-9.316c1.855-1.98 2.688-2.702 3.739-3.69 1.036 1.02 1.86 1.77 3.671 3.78 2.732 3.03 6.14 6.643 10.514 9.433s9.875 4.724 16.149 4.033c3.83-.422 7.85-1.788 12.07-4.26v-9.61c-5.12 3.905-9.396 5.544-12.944 5.935-4.227.465-7.686-.726-10.982-2.829-1.754-1.118-3.413-2.51-4.977-3.999 10.871-7.254 19.09-8.608 28.903-7.883v-7.927a70.657 70.657 0 0 0-2.12-.083c-10.437-.232-20.638 1.984-32.296 9.99a62.526 62.526 0 0 0-2.005-2.274c11.386-8.88 23.736-11.142 36.421-10.233V40.26a80.55 80.55 0 0 0-4.077-.14z"
          style="-inkscape-stroke:none;paint-order:stroke fill markers"
          transform="translate(-31.811 -30.281)"
        />
      </g>
    </svg>
    """
  end
end
