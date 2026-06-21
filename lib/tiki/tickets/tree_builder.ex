defmodule Tiki.Tickets.TreeBuilder do
  @moduledoc """
  Module for building a tree of ticket batches.
  """

  @doc """
  Constructs a digraph from the flat list of `%{batch: %TicketBatch{}, purchased: N}` rows
  returned by `Tiki.Tickets.batch_purchases_query/1`. Connects root batches to a synthetic
  fake-root vertex (id 0) so the whole forest becomes a single rooted tree.

  Returns `{graph, fake_root_id}`. The caller is responsible for calling `:digraph.delete/1`
  when done.
  """
  def build_graph(batch_rows) do
    fake_root = %{batch: %Tiki.Tickets.TicketBatch{id: 0, name: "fake_root"}, purchased: 0}
    graph = :digraph.new()

    for %{batch: %{id: id}} = node <- [fake_root | batch_rows] do
      :digraph.add_vertex(graph, id, node)
    end

    for %{batch: %{id: id, parent_batch_id: parent_id}} <- batch_rows do
      :digraph.add_edge(graph, id, parent_id || fake_root.batch.id)
    end

    {graph, fake_root.batch.id}
  end

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
