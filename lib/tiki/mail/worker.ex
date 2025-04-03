defmodule Tiki.Mail.Worker do
  use Oban.Worker, queue: :mail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email_args}}) do
    with email <- Tiki.Mailer.from_map(email_args),
         {:ok, _} <- Tiki.Mailer.deliver(email) do
      :ok
    end
  end
end
