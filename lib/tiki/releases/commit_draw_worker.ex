defmodule Tiki.Releases.CommitDrawWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [fields: [:args, :worker], states: [:available, :scheduled, :executing, :retryable]]

  alias Tiki.Releases

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "release_id" => release_id,
          "winner_ids" => winner_ids,
          "loser_ids" => loser_ids,
          "seed" => seed
        }
      }) do
    case Releases.commit_draw(release_id, winner_ids, loser_ids, seed) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
