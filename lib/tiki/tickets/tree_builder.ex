defmodule Tiki.Tickets.TreeBuilder do
  @moduledoc """
  Module for building a tree of ticket batches.
  """

  @doc """
  Builds a tree of ticket batches from a :digraph recursively.
  Propagates the purchased count up the tree and mutates the graph.

  ## Examples

      iex> build(graph, 0)
      %{batch: %Tiki.Tickets.TicketBatch{...}, children: [...], purchased: 0}
  """
  def build(graph, vertex) do
    children =
      for child <- :digraph.in_neighbours(graph, vertex) do
        build(graph, child)
      end

    {^vertex, label} = :digraph.vertex(graph, vertex)

    sum_purchased = Enum.reduce(children, 0, fn child, acc -> acc + child.purchased end)

    label =
      Map.put(label, :children, children)
      |> Map.put(:purchased, sum_purchased + label.purchased)

    :digraph.add_vertex(graph, vertex, label)
    label
  end

  @doc """
  Returns a map of available tickets for each batch in the tree, note
  that tree must be built first to propagate the purchased count up the tree.

  ## Examples

      iex> available(graph, 0)
      %{0 => :infinity, 2 => 3, ...}
  """
  def available(graph, node) do
    available_helper(graph, node, :infinity)
  end

  defp available_helper(graph, vertex, count) do
    {^vertex, label} = :digraph.vertex(graph, vertex)

    available =
      case label.batch.max_size do
        nil -> count
        max_size -> min(count, max_size - label.purchased)
      end

    children = :digraph.in_neighbours(graph, vertex)

    available_childs =
      Enum.reduce(children, %{}, fn child, acc ->
        Map.merge(acc, available_helper(graph, child, available))
      end)

    Map.merge(available_childs, %{vertex => available})
  end
end
