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
  Returns a changeset for a form submission, raises on error
  """
  def get_form_changeset!(form_id, response) do
    {:ok, changeset} = get_form_changeset(form_id, response)
    changeset
  end

  @doc """
  Returns a changeset for a form submission
  """
  def get_form_changeset(form_id, %Response{} = response) do
    attrs =
      response.question_responses
      |> Enum.reduce(%{}, fn qr, acc ->
        Map.put(acc, String.to_atom("#{qr.question_id}"), qr.answer || qr.multi_answer)
      end)

    get_form_changeset(form_id, attrs)
  end

  def get_form_changeset(form_id, attrs) do
    query =
      from f in Form,
        where: f.id == ^form_id,
        left_join: q in assoc(f, :questions),
        preload: [questions: q]

    case Repo.one(query) do
      nil ->
        {:error, "form not found"}

      form ->
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

        changeset =
          {data, types}
          |> Ecto.Changeset.cast(attrs, Map.keys(types))
          |> validate_required(form.questions)
          |> validate_options(form.questions)

        {:ok, changeset}
    end
  end

  defp validate_required(changeset, questions) do
    required =
      Enum.filter(questions, fn %{required: req} -> req end)
      |> Enum.map(fn %{id: id} -> String.to_atom("#{id}") end)

    Ecto.Changeset.validate_required(changeset, required)
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
              false -> [{field, "value must be an available option"}]
            end
          end)

        :multi_select ->
          acc
          |> Ecto.Changeset.validate_change(field, fn field, values ->
            case Enum.all?(values, &Enum.member?(q.options, &1)) do
              true -> []
              false -> [{field, "all values must be available options"}]
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
  def submit_response(form_id, ticket_id, attrs) do
    with {:ok, changeset} <- get_form_changeset(form_id, attrs),
         {:ok, data} <- Ecto.Changeset.apply_action(changeset, :create) do
      multi =
        Multi.new()
        |> Multi.one(:form, from(f in Form, where: f.id == ^form_id))
        |> Multi.insert(:response, fn %{form: form} ->
          Response.changeset(%Response{}, %{form_id: form.id, ticket_id: ticket_id})
        end)
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
      end
    else
      {:error, reason} ->
        {:error, reason}
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
  def update_form_response(form_response, attrs) do
    form_id = form_response.form_id

    with {:ok, changeset} <- get_form_changeset(form_id, attrs),
         {:ok, data} <- Ecto.Changeset.apply_action(changeset, :create) do
      multi =
        Multi.new()
        |> Multi.one(:form, from(f in Form, where: f.id == ^form_id))
        |> Multi.one(:response, from(r in Response, where: r.id == ^form_response.id))
        |> Multi.delete_all(
          :question_responses,
          fn %{response: response} ->
            from(qr in QuestionResponse, where: qr.response_id == ^response.id)
          end
        )
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
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a list of all rsponses for a form.
  """
  def list_responses!(form_id) do
    form_responses_query()
    |> where([f], f.id == ^form_id)
    |> Repo.one!()
  end

  NimbleCSV.define(CsvParser, separator: ",", escape: "\"")

  @doc """
  Exports all form answers for an event to a zip of csv files. Returns a tuple of
  the file name, and the binary of the zip file.
  """
  def export_event_forms(event_id) do
    # TODO: Refactor this to stream/chunk the results if this is too slow/consumes too much memory

    forms =
      form_responses_query()
      |> where([f], f.event_id == ^event_id)
      |> Repo.all()
      |> Enum.map(fn form ->
        questions = Enum.map(form.questions, fn question -> question.name end)

        responses =
          Enum.map(form.responses, fn response ->
            response_map =
              Enum.reduce(response.question_responses, %{}, fn qr, acc ->
                Map.put(acc, qr.question_id, qr.answer || qr.multi_answer)
              end)

            # Ensure all questions have a response
            Enum.map(form.questions, fn question ->
              Map.get(response_map, question.id, "")
            end)
          end)

        {~c"#{form.name}-responses.csv",
         [questions | responses] |> CsvParser.dump_to_iodata() |> IO.iodata_to_binary()}
      end)

    :zip.create(
      # just a name for internal bookkeeping
      ~c"tiki-event-#{event_id}-export-#{DateTime.utc_now() |> DateTime.to_string()}.zip",
      forms,
      [:memory]
    )
  end

  defp form_responses_query() do
    from f in Form,
      left_join: fr in assoc(f, :responses),
      left_join: qr in assoc(fr, :question_responses),
      left_join: q in assoc(f, :questions),
      preload: [
        responses: {fr, question_responses: qr},
        questions: q
      ]
  end
end
