This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
  custom classes must fully style the input

<!-- usage-rules-start -->
<!-- phoenix:elixir-start -->

## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you _must_ bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
  <!-- phoenix:elixir-end -->
  <!-- phoenix:phoenix-start -->

## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
  <!-- phoenix:phoenix-end -->
  <!-- phoenix:ecto-start -->

## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
  <!-- phoenix:ecto-end -->
  <!-- phoenix:html-start -->

## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`. **Never use `else if` or `elseif` in Elixir**, **always\*\* use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you _must_ annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

        <div id={@id}>
          {@my_assign}
          <%= if @some_block_condition do %>
            {@another_assign}
          <% end %>
        </div>

  and **Never** do this – the program will terminate with a syntax error:

        <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
        <div id="<%= @invalid_interpolation %>">
          {if @invalid_block_construct do}
          {end}
        </div>

  <!-- phoenix:html-end -->
  <!-- phoenix:liveview-start -->

## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- Remember anytime you use `phx-hook="MyHook"` and that js hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Never** write embedded `<script>` tags in HEEx. Instead always write your scripts and hooks in the `assets/js` directory and integrate them with the `assets/js/app.js` file

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are _not_ enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
        socket
        |> assign(:messages_empty?, messages == [])
        # reset the stream with the new messages
        |> stream(:messages, messages, reset: true)}
      end

- LiveView streams _do not support counting or empty states_. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @stream.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
  <!-- phoenix:liveview-end -->
  <!-- usage-rules-end -->

## Tailwind guidelines

- Tailwind is a utility-first CSS framework, so **always** use utility classes for styling, and **never** use classes like `bg-red-500` or `text-red-500`. Instead, use these colors defined for this project.

```
--color-background: #fff;
--color-foreground: oklch(14.1% 0.004 285.8);
--color-card: #fff;
--color-card-foreground: oklch(14.1% 0.004 285.8);
--color-popover: #fff;
--color-popover-foreground: oklch(14.1% 0.004 285.8);
--color-primary: oklch(21% 0.006 285.9);
--color-primary-foreground: oklch(98.48% 0 0);
--color-secondary: oklch(96.8% 0.001 286.4);
--color-secondary-foreground: oklch(21% 0.006 285.9);
--color-muted: oklch(96.8% 0.001 286.4);
--color-muted-foreground: oklch(55.2% 0.014 285.9);
--color-accent: oklch(96.8% 0.001 286.4);
--color-accent-foreground: oklch(21% 0.006 285.9);
--color-destructive: oklch(63.7% 0.208 25.3);
--color-destructive-foreground: oklch(98.48% 0 0);
--color-border: oklch(92% 0.004 286.3);
--color-input: oklch(92% 0.004 286.3);
--color-ring: oklch(21% 0.006 285.9);
--color-radius: 0.3rem;
--color-chart-1: oklch(52.9% 0.193 262.1);
--color-chart-2: oklch(69.8% 0.134 165.5);
--color-chart-3: oklch(72.3% 0.15 60.6);
--color-chart-4: oklch(61.9% 0.204 312.7);
--color-chart-5: oklch(61.2% 0.209 6.4);
--color-success: oklch(0.527 0.154 150.069);
--color-success-background: oklch(0.979 0.021 166.113);
--color-error: oklch(0.577 0.245 27.325);
--color-error-background: oklch(0.969 0.015 12.422);
```

For example, to style a muted text color, use `text-muted-foreground`. To style a background color, use `bg-background`.

## Translation guidelines

**All** hard coded strings that are user-facing should have translations in both English and Swedish. Translations are provided by the `Gettext` library. So, for example, if you have a `heex` template, use:

```
<p>{gettext("Hello")}</p>
```

and **never** use

```
<p>Hello</p>
```

Translations are provided in the `priv/gettext` directory. This can be generated using the command:

```
mix gettext.extract --merge --no-fuzzy
```

After extracting the translations, please fill in the missing translations in the `prib/gettext/sv/LC_MESSAGES` file.

## Authentication & Authorization

This application uses Phoenix 1.8 scopes pattern combined with the `let_me` library for centralized policy management.

### Phoenix 1.8 Scopes

The application uses a `Tiki.Accounts.Scope` struct to represent the current authentication and authorization context:

```elixir
%Tiki.Accounts.Scope{
  user: %User{},  # The authenticated user
  team: %Team{}   # The currently selected team (can be nil)
}
```

**Available in all LiveViews and Controllers:**

- `@current_scope` - The scope struct (preferred for new code)
- `@current_user` - The authenticated user (legacy, still supported)
- `@current_team` - The currently selected team (legacy, still supported)

**Scope is for identity/context only**. Do NOT add specific resources like events or orders to the scope. Use socket assigns for those.

### Authorization Layers (Defense in Depth)

The application uses three layers of authorization:

1. **Router/LiveSession (Coarse-grained)** - Use `on_mount` hooks for broad checks like "must be authenticated" or "must be manager"
2. **Context Functions (Fine-grained)** - Admin/mutating operations enforce authorization at the context layer
3. **LiveView Mount (Resource-specific)** - Use `Policy.authorize` for read operations when needed

### When to Enforce Authorization in Context Functions

**DO enforce in context for admin/mutating operations:**

```elixir
def update_membership(%Scope{} = scope, %Membership{} = membership, attrs) do
  team = get_team!(membership.team_id)

  with :ok <- Tiki.Policy.authorize(:team_update, scope.user, team) do
    membership
    |> Membership.changeset(attrs)
    |> Repo.update()
  end
end
```

**DON'T enforce for read operations used in multiple contexts:**

```elixir
# Public function - no authorization, used by both public and admin pages
def get_event!(id, opts \\ [])
```

### Pattern for Admin Context Functions

When creating admin/mutating operations:

```elixir
def dangerous_operation(%Tiki.Accounts.Scope{} = scope, resource_id, attrs) do
  resource = get_resource!(resource_id)

  with :ok <- Tiki.Policy.authorize(:resource_manage, scope.user, resource) do
    # Do the actual operation
    do_dangerous_operation(resource, attrs)
  end
end
```

**Benefits:**

- Authorization check cannot be forgotten - function signature requires scope
- Returns `{:error, :unauthorized}` if user lacks permission
- LiveView code becomes simpler - no need to duplicate authorization checks

### Policy Definitions

Policies are defined in `lib/tiki/policy.ex` using the `let_me` DSL:

```elixir
object :team do
  action :update do
    allow hive: "admin"
    allow team_role: :admin
  end
end
```

Policy checks are implemented in `lib/tiki/policy/checks.ex`.

### Testing Authorization

For tests, the application uses a mock permission service. To grant permissions in tests:

```elixir
# In test setup
user = user_fixture()
team = team_fixture()

# Grant team admin permission by making user a member
%Membership{user_id: user.id, team_id: team.id, role: :admin}
|> Repo.insert!()

# Or for hive permissions (admin, audit, etc)
PermissionServiceMock.grant_permission(user, "admin")
```

### Migration Strategy

- **New features**: Always use scopes and scoped context functions
- **Existing code**: Migrate opportunistically when touching code
- **Priority**: Admin/mutating operations first (highest security benefit)
