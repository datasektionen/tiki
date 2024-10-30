defmodule Tiki.Policy.Checks do
  alias Tiki.Accounts.User

  def role(%User{role: role}, _object, role), do: true
  def role(_, _, _), do: false
end
