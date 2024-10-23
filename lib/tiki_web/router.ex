defmodule TikiWeb.Router do
  use TikiWeb, :router

  import TikiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {TikiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :fetch_locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TikiWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", TikiWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tiki, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TikiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TikiWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{TikiWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", TikiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TikiWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      live "/events", EventLive.Index, :index
      live "/events/:id", EventLive.Show, :index
      live "/events/:id/purchase", EventLive.Show, :purchase
    end

    scope "/admin", AdminLive do
      live_session :require_admin_user,
        on_mount: [
          {TikiWeb.UserAuth, :ensure_admin},
          TikiWeb.Nav
        ],
        layout: {TikiWeb.Layouts, :admin} do
        live "/", Dashboard.Index, :index

        live "/user-settings", User.Settings, :index

        # General event stuff
        live "/events", Event.Index, :index
        live "/events/new", Event.Index, :new

        scope "/events/:id" do
          # Event dashboard
          live "/", Event.Show, :show

          # Event settings
          live "/settings", Event.Show, :edit

          # Tickets overview
          live "/tickets", Ticket.Index, :index

          # Ticket type settings
          live "/ticket-types/new", Ticket.Index, :new_ticket_type

          live "/ticket-types/:ticket_type_id/edit",
               Ticket.Index,
               :edit_ticket_type

          # Ticket batch settings
          live "/tickets/batches/new", Ticket.Index, :new_batch
          live "/tickets/batches/:batch_id/edit", Ticket.Index, :edit_batch

          # Check-in
          live "/check-in", Ticket.Checkin, :index

          # Registrations
          live "/attendees", Attendees.Index, :index
          live "/queue", Attendees.Index, :index
          live "/contact", Contact.Index, :index
          live "/attendees/:ticket_id", Attendees.Show, :show

          # Forms
          live "/forms", Forms.Index, :index
          live "/forms/:id/edit", Forms.Edit
        end
      end
    end
  end

  scope "/", TikiWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{TikiWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope("/oidcc", TikiWeb) do
    pipe_through :browser
    get "/authorize", OidccController, :authorize
    get "/callback", OidccController, :callback
    post "/callback", OidccController, :callback
  end
end
