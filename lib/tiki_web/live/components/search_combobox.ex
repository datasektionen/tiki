defmodule TikiWeb.LiveComponents.SearchCombobox do
  @moduledoc """
  A live component for a searchable combobox. It allows the user to search for
  items and select one of them.


  ## Example usage

  ```elixir
  <.live_component
    id="user-select-component"
    module={TikiWeb.LiveComponents.SearchCombobox}
    search_fn={&Tiki.Accounts.search_users/1}
    all_fn={&Tiki.Accounts.list_users/1}
    map_fn={fn user -> {user.id, user.email} end}
    field={@form[:user_id]}
    label={gettext("User")}
    chosen={@form[:user_id].value}
    placeholder={
      Ecto.assoc_loaded?(@form.data.user) && @form[:user].value &&
         @form[:user].value.email
    }
  />
  ```

  ## Assigns

  * `search_fn` - A function that takes a query and returns a list of results.
  * `all_fn` - A function that returns all results, the second argument is a keyword list with options. This
      should accept a keyword with the option `:limit` which specifies the maximum number of results to return.
  * `map_fn` - A function that maps the results from both `search_fn` and `all_fn` to a tuple of id and value. The
      value is what is displayed in the combobox, and the id is used to identify the chosen item.
  * `field` - The form field that the chosen item is stored in.
  * `label` - The label for the combobox.
  * `chosen` - The id of the chosen item, used to preselect an already chosen item.
  * `placeholder` - The placeholder text for the combobox, used only initially when rendered.
  """

  use TikiWeb, :live_component

  @display_limit 5

  @impl true
  def update(assigns, socket) do
    chosen = Map.get(assigns, :chosen, nil)
    placeholder = Map.get(assigns, :placeholder, "")
    all_fn = Map.get(assigns, :all_fn, fn -> [] end)
    map_fn = Map.get(assigns, :map_fn, fn x -> x end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       results: [],
       chosen: chosen,
       all_fn: all_fn,
       map_fn: map_fn
     )
     |> assign_new(:query, fn -> placeholder end)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    results =
      socket.assigns.search_fn.(query)
      |> Enum.take(@display_limit)

    {:noreply, assign(socket, results: results, query: query)}
  end

  @impl true
  def handle_event("show_all", _query, socket) do
    results = socket.assigns.all_fn.(limit: @display_limit)

    {:noreply, assign(socket, results: results)}
  end

  @impl true
  def handle_event("chosen", %{"id" => id, "value" => value}, socket) do
    {:noreply, assign(socket, chosen: id, query: value, results: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div>
        <label for="combobox" class="text-foreground block text-sm font-medium leading-6">
          <%= @label %>
        </label>
        <div class="relative mt-2">
          <input
            id="combobox"
            type="text"
            class="py-[7px] px-[11px] text-foreground border-input mt-2 block w-full rounded-lg text-sm focus:ring-ring focus:border-input focus:outline-none focus:ring-2 sm:leading-6"
            role="combobox"
            aria-controls="options"
            aria-expanded="false"
            placeholder={gettext("Search...")}
            phx-target={@myself}
            phx-change="search"
            name="q"
            value={@query}
            autocomplete={:off}
          />
          <button
            type="button"
            class="absolute inset-y-0 right-0 flex items-center rounded-r-md px-2 focus:outline-none"
            phx-click="show_all"
            phx-target={@myself}
          >
            <svg
              class="text-muted-foreground h-5 w-5"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 3a.75.75 0 01.55.24l3.25 3.5a.75.75 0 11-1.1 1.02L10 4.852 7.3 7.76a.75.75 0 01-1.1-1.02l3.25-3.5A.75.75 0 0110 3zm-3.76 9.2a.75.75 0 011.06.04l2.7 2.908 2.7-2.908a.75.75 0 111.1 1.02l-3.25 3.5a.75.75 0 01-1.1 0l-3.25-3.5a.75.75 0 01.04-1.06z"
                clip-rule="evenodd"
              />
            </svg>
          </button>

          <div
            :if={@results != []}
            class="bg-background absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm"
            id="options"
            role="listbox"
          >
            <li
              :for={{id, value} <- @results |> Enum.map(&@map_fn.(&1))}
              class="text-foreground relative cursor-default select-none py-2 pr-9 pl-3 hover:bg-gray-50"
              role="option"
              tabindex="-1"
              phx-click={JS.push("chosen", value: %{id: id, value: value})}
              phx-target={@myself}
            >
              <span class={[
                "block truncate",
                @chosen == id && "font-semibold"
              ]}>
                <%= value %>
              </span>

              <span
                :if={@chosen == id}
                class="absolute inset-y-0 right-0 flex items-center pr-4 text-indigo-600"
              >
                <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
              </span>
            </li>
          </div>
        </div>
      </div>

      <.input field={@field} type="hidden" value={@chosen} />
    </div>
    """
  end
end
