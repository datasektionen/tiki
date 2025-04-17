defmodule Tiki.Types.DatetimeStockholm do
  use Ecto.Type

  # still store as utc_datetime
  def type, do: :utc_datetime

  def cast(value), do: cast_stockholm_datetime(value)

  defp cast_stockholm_datetime(nil), do: {:ok, nil}

  defp cast_stockholm_datetime("-" <> rest) do
    with {:ok, utc_datetime} <- cast_stockholm_datetime(rest) do
      {:ok, %{utc_datetime | year: utc_datetime.year * -1}}
    end
  end

  defp cast_stockholm_datetime(
         <<year::4-bytes, ?-, month::2-bytes, ?-, day::2-bytes, sep, hour::2-bytes, ?:,
           minute::2-bytes>>
       )
       when sep in [?\s, ?T] do
    with {:ok, naive_dt} <-
           NaiveDateTime.new(to_i(year), to_i(month), to_i(day), to_i(hour), to_i(minute), 0),
         {:ok, dt} <- to_utc(naive_dt) do
      {:ok, dt}
    else
      _ -> :error
    end
  end

  defp cast_stockholm_datetime(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(binary) do
          {:ok, naive_datetime} -> to_utc(naive_datetime)
          {:error, _} -> :error
        end

      {:error, _} ->
        :error
    end
  end

  defp cast_stockholm_datetime(%DateTime{} = datetime) do
    case datetime |> DateTime.to_unix(:microsecond) |> DateTime.from_unix(:microsecond) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end

  defp cast_stockholm_datetime(%NaiveDateTime{} = datetime), do: to_utc(datetime)

  def load(%DateTime{} = datetime), do: from_utc(datetime)
  def load(%NaiveDateTime{} = datetime), do: from_utc(datetime)
  def load(_), do: :error

  def dump(%DateTime{time_zone: "Etc/UTC"} = dt), do: {:ok, dt}
  def dump(%DateTime{} = dt), do: {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}
  def dump(_), do: :error

  defp to_utc(%NaiveDateTime{} = datetime) do
    case DateTime.from_naive(datetime, "Europe/Stockholm") do
      {:ok, datetime} -> {:ok, DateTime.shift_zone!(datetime, "Etc/UTC")}
      _ -> :error
    end
  end

  defp from_utc(%DateTime{time_zone: "Etc/UTC"} = datetime) do
    {:ok, DateTime.shift_zone(datetime, "Europe/Stockholm")}
  end

  defp from_utc(%NaiveDateTime{} = datetime) do
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, datetime} -> {:ok, DateTime.shift_zone!(datetime, "Europe/Stockholm")}
      _ -> :error
    end
  end

  defp to_i(bin) when is_binary(bin) and byte_size(bin) < 32 do
    case Integer.parse(bin) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
