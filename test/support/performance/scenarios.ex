defmodule Tiki.Performance.Scenarios do
  @moduledoc """
  Realistic event scenario specs for performance tests.

  Each scenario is a plain map describing the batch hierarchy, ticket types,
  and buyer demand distribution. All capacities are base values multiplied by
  `PERF_SCALE` at runtime.

  ## Spec shape

      %{
        load_factor: float(),       # buyers per batch = capacity × load_factor
        batches: [batch_spec()]
      }

  Where `batch_spec` is:

      %{
        name:         String.t(),
        capacity:     pos_integer(),          # max_size; optional on children
        min_size:     pos_integer(),          # optional
        ticket_types: [ticket_type_spec()],   # present on leaf batches
        batches:      [batch_spec()]          # present on parent batches
      }

  And `ticket_type_spec`:

      %{
        key:    atom(),        # used to look up the type in test assertions
        name:   String.t(),
        price:  non_neg_integer(),
        weight: pos_integer()  # relative buyer demand within this batch
      }
  """

  @doc """
  Single batch, single ticket type.
  """
  def single_batch do
    %{
      load_factor: 2.0,
      batches: [
        %{
          name: "General",
          capacity: 10,
          ticket_types: [
            %{key: :general, name: "General Admission", price: 0, weight: 1}
          ]
        }
      ]
    }
  end

  @doc """
  Two independent date batches sharing no parent capacity. Common pattern.

  Base capacities: 20 (Friday), 15 (Saturday).
  """
  def multi_date do
    %{
      load_factor: 2.0,
      batches: [
        %{
          name: "Friday",
          capacity: 20,
          ticket_types: [
            %{key: :regular, name: "Regular", price: 200, weight: 3},
            %{key: :student, name: "Student", price: 150, weight: 1}
          ]
        },
        %{
          name: "Saturday",
          capacity: 15,
          ticket_types: [
            %{key: :regular, name: "Regular", price: 200, weight: 3},
            %{key: :student, name: "Student", price: 150, weight: 1}
          ]
        }
      ]
    }
  end

  @doc """
  Parent batch capping a shared pool across two child batches, plus a
  separate VIP batch.

  Base capacities: parent 30, students 20, alumni 15, VIP 5.
  Students (20) + alumni (15) = 35 possible, but parent caps at 30.
  """
  def shared_pool do
    %{
      load_factor: 2.0,
      batches: [
        %{
          name: "General",
          capacity: 30,
          batches: [
            %{
              name: "Students",
              capacity: 20,
              ticket_types: [
                %{key: :regular, name: "Regular", price: 0, weight: 3},
                %{key: :student, name: "Student", price: 0, weight: 2}
              ]
            },
            %{
              name: "Alumni",
              capacity: 15,
              ticket_types: [
                %{key: :alumni, name: "Alumni", price: 0, weight: 1}
              ]
            }
          ]
        },
        %{
          name: "VIP",
          capacity: 5,
          ticket_types: [
            %{key: :vip, name: "VIP", price: 0, weight: 1}
          ]
        }
      ]
    }
  end
end
