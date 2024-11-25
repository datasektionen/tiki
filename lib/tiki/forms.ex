defmodule Tiki.Forms do
  @moduledoc """
  The Forms context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo
  alias Ecto.Multi

  alias Tiki.Forms.Form
  alias Tiki.Forms.QuestionResponse
  alias Tiki.Forms.Response

  @doc """
  Returns all forms for an event.

  ## Examples

      iex> list_forms_for_event(123)
      [%Form{}, ...]

      iex> list_forms_for_event(456)
      []

  """
  def list_forms_for_event(event_id) do
    Repo.all(from f in Form, where: f.event_id == ^event_id)
  end

  @doc """
  Gets a single form, including all its questions.

  Raises `Ecto.NoResultsError` if the Form does not exist.

  ## Examples

      iex> get_form!(123)
      %Form{}

      iex> get_form!(456)
      ** (Ecto.NoResultsError)

  """
  def get_form!(id) do
    Repo.one!(
      from f in Form,
        where: f.id == ^id,
        left_join: q in assoc(f, :questions),
        preload: [questions: q]
    )
  end

  @doc """
  Creates a form.

  ## Examples

      iex> create_form(%{field: value})
      {:ok, %Form{}}

      iex> create_form(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form(attrs \\ %{}) do
    %Form{}
    |> Form.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a form.

  ## Examples

      iex> update_form(form, %{field: new_value})
      {:ok, %Form{}}

      iex> update_form(form, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form(%Form{} = form, attrs) do
    form
    |> Form.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a form.

  ## Examples

      iex> delete_form(form)
      {:ok, %Form{}}

      iex> delete_form(form)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form(%Form{} = form) do
    Repo.delete(form)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form changes.

  ## Examples

      iex> change_form(form)
      %Ecto.Changeset{data: %Form{}}

  """
  def change_form(%Form{} = form, attrs \\ %{}) do
    Form.changeset(form, attrs)
  end

  @doc """
  Retruns a changeset for a form submission
  """
  def get_form_changeset!(form_id, %Response{} = response) do
    attrs =
      response.question_responses
      |> Enum.reduce(%{}, fn qr, acc ->
        Map.put(acc, String.to_atom("#{qr.question_id}"), qr.answer || qr.multi_answer)
      end)

    get_form_changeset!(form_id, attrs)
  end

  def get_form_changeset!(form_id, attrs) do
    query =
      from f in Form,
        where: f.id == ^form_id,
        left_join: q in assoc(f, :questions),
        preload: [questions: q]

    form = Repo.one!(query)

    data = %{}

    types =
      Enum.reduce(form.questions, %{}, fn q, acc ->
        case q.type do
          :multi_select ->
            Map.put(acc, String.to_atom("#{q.id}"), {:array, :string})

          _ ->
            Map.put(acc, String.to_atom("#{q.id}"), :string)
        end
      end)

    {data, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> validate_required(form.questions)
    |> validate_required_multi(form.questions)
    |> validate_options(form.questions)
  end

  defp validate_required(changeset, questions) do
    required =
      Enum.filter(questions, fn %{required: req} -> req end)
      |> Enum.map(fn %{id: id} -> String.to_atom("#{id}") end)

    Ecto.Changeset.validate_required(changeset, required)
  end

  defp validate_required_multi(changeset, questions) do
    Enum.reduce(questions, changeset, fn q, acc ->
      field = String.to_atom("#{q.id}")

      if q.type == :multi_select && q.required do
        acc
        |> Ecto.Changeset.validate_change(field, fn field, values ->
          case values do
            [] -> [{field, "At least one value must be selected"}]
            _ -> []
          end
        end)
      else
        acc
      end
    end)
  end

  defp validate_options(changeset, questions) do
    Enum.reduce(questions, changeset, fn q, acc ->
      field = String.to_atom("#{q.id}")

      case q.type do
        :select ->
          acc
          |> Ecto.Changeset.validate_change(field, fn field, value ->
            case value in q.options do
              true -> []
              false -> [{field, "Value must be an availible option"}]
            end
          end)

        :multi_select ->
          acc
          |> Ecto.Changeset.validate_change(field, fn field, values ->
            case Enum.all?(values, &Enum.member?(q.options, &1)) do
              true -> []
              false -> [{field, "All values must be availible options"}]
            end
          end)

        _ ->
          acc
      end
    end)
  end

  @doc """
  Submits a form response for a user and form. Creates a response, as well as
  all the question responses for the form.

  ## Examples

      iex> submit_response(123, %Response{question_responses: [%{question_id: 1, answer: "Answer 1"}]})
      {:ok, %Response{}}

      iex> submit_response(456, %Response{})
      {:error, %Ecto.Changeset{}}

  """
  def submit_response(%Response{form_id: form_id} = response) do
    changeset = get_form_changeset!(form_id, response)

    case changeset |> Ecto.Changeset.apply_action(:create) do
      {:ok, data} ->
        multi =
          Multi.new()
          |> Multi.one(:form, from(f in Form, where: f.id == ^form_id))
          |> Multi.insert(:response, fn %{form: form} -> %Response{form_id: form.id} end)
          |> Multi.merge(fn %{response: response} ->
            Enum.reduce(data, Multi.new(), fn {key, val}, acc ->
              id = Atom.to_string(key) |> String.to_integer()

              Multi.insert(acc, "question_response_#{key}", fn _ ->
                QuestionResponse.from_answer(response, id, val)
              end)
            end)
          end)
          |> Multi.run(:preloaded_response, fn repo, %{response: response} ->
            {:ok, repo.preload(response, :question_responses)}
          end)

        case Repo.transaction(multi) do
          {:ok, %{preloaded_response: response}} ->
            {:ok, response}

          other ->
            other
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a form response for a form. Modifies the response, as well as
  replaces all the question responses with new answers.

  ## Examples

      iex> update_form_response(123, form_response, %{field: new_value})
      {:ok, %Response{}}

      iex> update_form_response(123, form_response, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form_response(form_id, form_response, attrs) do
    changeset = get_form_changeset!(form_id, attrs)

    case Ecto.Changeset.apply_action(changeset, :create) do
      {:ok, data} ->
        question_responses =
          Enum.map(data, fn {key, val} ->
            id = Atom.to_string(key) |> String.to_integer()

            case val do
              ans when is_list(ans) -> %QuestionResponse{question_id: id, multi_answer: ans}
              ans -> %QuestionResponse{question_id: id, answer: ans}
            end
          end)

        multi =
          Multi.new()
          |> Multi.delete_all(
            :question_responses,
            from(qr in QuestionResponse, where: qr.response_id == ^form_response.id)
          )

        {_n, multi} =
          Enum.reduce(question_responses, {0, multi}, fn qr, {n, m} ->
            {n + 1,
             Multi.insert(m, n, fn _ ->
               %QuestionResponse{qr | response_id: form_response.id}
             end)}
          end)

        Repo.transaction(multi)

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
