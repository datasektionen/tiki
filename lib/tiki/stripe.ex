defmodule Tiki.Stripe do
  alias __MODULE__

  def new(options \\ []) do
    Req.new(
      base_url: "https://api.stripe.com/v1",
      auth: {:bearer, Application.fetch_env!(:tiki, :stripe_api_key)}
    )
    |> Req.merge(options)
  end

  def request(options) do
    options =
      case Keyword.get(options, :form) do
        form when is_map(form) -> Keyword.put(options, :form, flatten_form(form))
        _ -> options
      end

    case Req.request(new(), options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{body: body}} -> {:error, body}
      {:error, _} = err -> err
    end
  end

  defp flatten_form(params, prefix \\ nil) do
    Enum.flat_map(params, fn {key, value} ->
      key = if prefix, do: "#{prefix}[#{key}]", else: to_string(key)

      if is_map(value) and not is_struct(value) do
        flatten_form(value, key)
      else
        [{key, value}]
      end
    end)
  end

  defmodule PaymentIntent do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :id, :string
      field :client_secret, :string
      field :status, :string
      field :amount, :integer
      field :payment_method, :string
      field :currency, :string
      field :metadata, :map
    end

    def create(params) do
      with {:ok, body} <- Stripe.request(method: :post, url: "/payment_intents", form: params),
           do: {:ok, Tiki.Utils.cast_to_struct(__MODULE__, body)}
    end

    def retrieve(id) do
      with {:ok, body} <- Stripe.request(url: "/payment_intents/#{id}"),
           do: {:ok, Tiki.Utils.cast_to_struct(__MODULE__, body)}
    end
  end

  defmodule Card do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :brand, :string
      field :last4, :string
      field :exp_month, :integer
      field :exp_year, :integer
    end
  end

  defmodule PaymentMethod do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :id, :string
      embeds_one :card, Stripe.Card
    end

    def retrieve(id) do
      with {:ok, body} <- Stripe.request(url: "/payment_methods/#{id}"),
           do: {:ok, Tiki.Utils.cast_to_struct(__MODULE__, body)}
    end
  end
end
