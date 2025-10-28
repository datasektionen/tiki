defmodule TikiWeb.EventController do
  use TikiWeb, :controller

  def export_form_answers(conn, %{"event_id" => event_id}) do
    event = Tiki.Events.get_event!(event_id)

    with :ok <- Tiki.Policy.authorize(:event_view, conn.assigns.current_scope.user, event),
         {:ok, {name, binary}} <- Tiki.Forms.export_event_forms(event_id) do
      conn
      |> put_resp_content_type("application/zip")
      |> put_resp_header("content-disposition", ~s(attachment; filename=#{name}))
      |> send_resp(200, binary)
    else
      {:error, :unauthorized} -> conn |> put_status(403) |> text("Unauthorized")
      {:error, error} -> conn |> put_status(500) |> text(error)
    end
  end
end
