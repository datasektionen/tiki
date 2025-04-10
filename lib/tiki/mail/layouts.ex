defmodule Tiki.Mail.Layouts do
  use Phoenix.Component

  use Gettext, backend: TikiWeb.Gettext

  @doc """
  Default template.
  """

  attr :title, :string, required: true
  slot :section

  def default(assigns) do
    ~H"""
    <mjml>
      <mj-head>
        <mj-preview>{@title}</mj-preview>
        <mj-attributes>
          <mj-all font-family="'Helvetica Neue', Helvetica, Arial, sans-serif"></mj-all>
          <mj-text
            font-weight="400"
            font-size="14px"
            color="#18181b"
            line-height="24px"
            font-family="'Helvetica Neue', Helvetica, Arial, sans-serif"
          >
          </mj-text>
        </mj-attributes>
      </mj-head>
      <mj-body background-color="#EFEFEF" width="600px">
        <mj-wrapper padding-top="0" padding-bottom="0" padding-left="10px">
          <mj-section>
            <mj-column>
              <mj-image
                src={"#{TikiWeb.Endpoint.url()}/images/logo_200.png"}
                align="left"
                alt="Tiki logo"
                width="64px"
              >
              </mj-image>
            </mj-column>
          </mj-section>
        </mj-wrapper>

        <%= for {section, i} <- Enum.with_index(@section) do %>
          <mj-section
            border-radius={if i == 0, do: "10px 10px 0 0", else: "0px"}
            padding-left="10px"
            padding-right="10px"
            background-color="#fff"
            padding-bottom="8px"
          >
            {render_slot(section)}
          </mj-section>
        <% end %>

        <mj-section
          background-color="#ffffff"
          padding-left="10px"
          padding-right="10px"
          padding-top="0"
          text-align="left"
          border-radius="0px 0px 10px 10px"
        >
          <.divider />
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text font-size="14px">
              Tiki is an event platform developed by and for the Computer Science Chapter at KTH.<br />

              <a
                target="_blank"
                href="https://tiki.datasektionen.se"
                style="color: #1a73e8; text-decoration: none;"
              >
                tiki.datasektionen.se
              </a>
            </mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
    """
  end

  attr :rest, :global, default: %{}

  def divider(assigns) do
    ~H"""
    <mj-divider border-color="#e4e4e7" border-width="1px" {@rest} />
    """
  end

  attr :href, :string, required: true
  attr :align, :string, default: "left"
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <mj-button
      background-color="#18181b"
      color="#fff"
      border-radius="8px"
      font-size="14px"
      font-weight="bold"
      href={@href}
      align={@align}
      phx-no-format
    >{render_slot(@inner_block)}</mj-button>
    """
  end
end
