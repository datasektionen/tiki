defmodule Tiki.Mailer do
  use Swoosh.Mailer, otp_app: :tiki

  def to_map(%Swoosh.Email{} = email) do
    %{
      "to" => contact_to_map(email.to),
      "from" => contact_to_map(email.from),
      "subject" => email.subject,
      "html_body" => email.html_body,
      "attachments" => attachements_to_map(email.attachments)
    }
  end

  def from_map(args) do
    %{
      "to" => to,
      "from" => from,
      "subject" => subject,
      "html_body" => html_body,
      "attachments" => attachments
    } = args

    mail =
      Swoosh.Email.new(
        to: map_to_contact(to),
        from: map_to_contact(from),
        subject: subject,
        html_body: html_body
      )

    Enum.reduce(attachments, mail, fn attachment, mail ->
      Swoosh.Email.attachment(mail, map_to_attachement(attachment))
    end)
  end

  defp contact_to_map(info) when is_list(info) do
    Enum.map(info, &contact_to_map/1)
  end

  defp contact_to_map({name, email}) do
    %{"name" => name, "email" => email}
  end

  defp map_to_contact(info) when is_list(info) do
    Enum.map(info, &map_to_contact/1)
  end

  defp map_to_contact(%{"name" => name, "email" => email}) do
    {name, email}
  end

  defp attachements_to_map(attachements) do
    Enum.map(attachements, &Map.from_struct/1)
  end

  defp map_to_attachement(attachement) do
    %Swoosh.Attachment{
      filename: attachement["filename"],
      content_type: attachement["content_type"],
      path: attachement["path"],
      data: attachement["data"],
      type: attachement["type"],
      headers: attachement["headers"],
      cid: attachement["cid"]
    }
  end
end
