defmodule Tiki.Epmd do
  @moduledoc false

  @distro_version 5

  # we don't run any epmd process, so dont start anything
  def start_link, do: :ignore
  def stop, do: :ok
  def names(_host), do: {:error, :address}

  def register_node(name, port, _family), do: register_node(name, port)
  def register_node(_name, _port), do: {:ok, :rand.uniform(3)}

  # Tells the distribution layer which port to listen on locally.
  def listen_port_please(name, _host) do
    # for rpc (eg. iex remote sessions), choose a random port
    if String.match?(to_string(name), ~r/^(rpc|rem)-/) do
      {:ok, 0}
    else
      {:ok, local_dist_port()}
    end
  end

  # Returns IP + port + version in one call.
  # Port is encoded in the node name as tiki-<port>-<id>@<host>
  def address_please(name, host, _family) do
    name_str = to_string(name)

    if "#{name_str}@#{host}" == node() |> to_string() do
      {:ok, {127, 0, 0, 1}, local_dist_port(), @distro_version}
    else
      host_chars = if is_binary(host), do: String.to_charlist(host), else: host

      with {:ok, address} <- :inet.getaddr(host_chars, :inet),
           {:ok, port} <- port_from_name(name_str) do
        {:ok, address, port, @distro_version}
      end
    end
  end

  defp port_from_name(name) do
    case String.split(name, "-") do
      ["tiki", port_str | _] ->
        case Integer.parse(port_str) do
          {port, ""} -> {:ok, port}
          _ -> {:error, :bad_port}
        end

      _ ->
        {:error, :unknown_name_format}
    end
  end

  defp local_dist_port do
    case System.get_env("ERL_DIST_PORT") do
      nil -> raise "ERL_DIST_PORT is not set"
      port -> String.to_integer(port)
    end
  end
end
