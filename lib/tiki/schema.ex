defmodule Tiki.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @timestamps_opts [type: :naive_datetime_usec]
    end
  end
end
