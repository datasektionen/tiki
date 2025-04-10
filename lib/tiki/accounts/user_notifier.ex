defmodule Tiki.Accounts.UserNotifier do
  use Tiki.Mail.Layouts

  import Swoosh.Email
  alias Tiki.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Tiki", "noreply-tiki@datasektionen.se"})
      |> subject(subject)
      |> html_body(body)
      |> Tiki.Mailer.to_map()

    Tiki.Mail.Worker.new(%{email: email})
    |> Oban.insert()
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    assigns = %{user: user, url: url}

    html = ~H"""
    <Tiki.Mail.Layouts.default title={gettext("Confirm your account")}>
      <:section>
        <mj-column>
          <mj-text font-size="24px" font-weight="bold">{gettext("Welcome to Tiki!")}</mj-text>
          <mj-text>
            {gettext("Hi %{email}! You can confirm your account by visiting the link below.",
              email: @user.email
            )}
          </mj-text>

          <.button href={@url}>{gettext("Confirm account")}</.button>

          <mj-text>
            {gettext("If you didn't create an account with us, please ignore this.")}
          </mj-text>
        </mj-column>
      </:section>
    </Tiki.Mail.Layouts.default>
    """

    deliver(
      user.email,
      gettext("Welcome to Tiki! Confirm your account"),
      Tiki.Mail.Mjml.to_html!(html)
    )
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    assigns = %{user: user, url: url}

    html = ~H"""
    <Tiki.Mail.Layouts.default title={gettext("Confirm your email update")}>
      <:section>
        <mj-column>
          <mj-text>
            {gettext("Hi %{email}! You can change your email on Tiki by visiting the link below.",
              email: @user.email
            )}
          </mj-text>

          <.button href={@url}>{gettext("Update email")}</.button>

          <mj-text>
            {gettext("If you didn't request this change, please ignore this.")}
          </mj-text>
        </mj-column>
      </:section>
    </Tiki.Mail.Layouts.default>
    """

    deliver(user.email, gettext("Update email instructions"), Tiki.Mail.Mjml.to_html!(html))
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    assigns = %{user: user, url: url}

    html = ~H"""
    <Tiki.Mail.Layouts.default title={gettext("Use this this link to log in")}>
      <:section>
        <mj-column>
          <mj-text font-size="24px" font-weight="bold">{gettext("Here is your login link!")}</mj-text>
          <mj-text>
            {gettext(
              "Hi %{email}! You recently requested a login link for your account. Here it comes!",
              email: @user.email
            )}
          </mj-text>

          <.button href={@url}>{gettext("Log in")}</.button>

          <mj-text>
            {gettext(
              "The link is valid for 20 minutes, and can only be used once. If you didn't request this email, please ignore this."
            )}
          </mj-text>
        </mj-column>
      </:section>
    </Tiki.Mail.Layouts.default>
    """

    deliver(user.email, gettext("Your log in link for Tiki"), Tiki.Mail.Mjml.to_html!(html))
  end
end
