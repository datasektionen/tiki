defmodule Tiki.Mail.SpamAdapter do
  @moduledoc """
  A module that sends mails using the [Spam API](https://github.com/datasektionen/spam)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Tiki.Mail.SpamAdapter,
        access_token: {:system, "SPAM_API_TOKEN"}

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Required config parameters
      - `:api_key` - The API key for the Spam API
  """
  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @spam_url "https://spam.datasektionen.se/api/sendmail"

  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"}
    ]

    api_key =
      config[:api_key]

    body =
      email
      |> prepare_body()
      |> prepare_key(api_key)
      |> Swoosh.json_library().encode!()

    case Swoosh.ApiClient.post(@spam_url, headers, body, email) do
      {:ok, 200, _headers, body} ->
        {:ok, parse_response(body)}

      {:ok, code, _headers, body} when code >= 400 and code <= 599 ->
        {:error, {code, parse_response(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body) do
    body
  end

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_bcc(email)
    |> prepare_reply_to(email)
    |> prepare_subject(email)
    |> prepare_content(email)
    |> prepare_template(email)
    |> prepare_attachments(email)
  end

  defp prepare_from(body, %Email{from: from}), do: Map.put(body, :from, render_recipient(from))

  defp prepare_to(body, %Email{to: to}) do
    Map.put(body, :to, render_recipient(to))
  end

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %Email{bcc: bcc}) do
    Map.put(body, :bcc, render_recipient(bcc))
  end

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_content(body, %{html_body: content}), do: Map.put(body, :content, content)

  defp prepare_reply_to(body, %{reply_to: to}), do: Map.put(body, "replyTo", render_recipient(to))

  defp prepare_template(body, %{provider_options: %{template: template}}),
    do: Map.put(body, :template, template)

  defp prepare_template(body, _), do: Map.put(body, :template, "none")

  defp prepare_key(body, api_key) do
    Map.put(body, :key, api_key)
  end

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments = Enum.filter(attachments, &(&1.type == :attachment))
    Map.put(body, :files, Enum.map(attachments, &prepare_file(&1)))
  end

  defp prepare_file(attachment) do
    %{
      "contentType" => attachment.content_type,
      filename: attachment.filename,
      content: Base.encode64(attachment.data)
    }
  end

  defp render_recipient(nil), do: []
  defp render_recipient({name, address}), do: %{name: name, address: address}
  defp render_recipient(list) when is_list(list), do: Enum.map(list, &render_recipient/1)
end
