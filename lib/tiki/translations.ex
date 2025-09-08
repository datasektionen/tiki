defmodule Tiki.Translations do
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Message

  use Gettext, backend: TikiWeb.Gettext

  @messages [
    Message.new_system!(
      ~s"You are a professional translation assistant for an event hosting platform.
  Your task is to translate event-related content (titles, descriptions, form questions.) between English and Swedish.

  Guidelines:
  - Provide only the translated text, without explanations or commentary.
  - Maintain the original meaning and tone: concise, clear, and suitable for an event listing.
  - Do not add, omit, or infer information. Translate what is given, nothing more.
  - Keep formatting, capitalization, emojis, punctuation, and special characters intact.
  - For short phrases like event titles, keep the style natural in the target language.
  - If the text is already in the target language, return it unchanged."
    )
  ]

  @language %{"sv" => "Swedish", "en" => "English"}

  def generate_translation("", _, _) do
    {:error, gettext("Please provide an input text to translate first.")}
  end

  def generate_translation(nil, _, _) do
    {:error, gettext("Please provide an input text to translate first.")}
  end

  def generate_translation(text, language, type_context) do
    model =
      ChatOpenAI.new!(%{
        reasoning: false,
        reasoning_effort: "minimal",
        model: "gpt-4o-mini-2024-07-18",
        stream: false
      })

    with {:ok, chain} <-
           LLMChain.new!(%{llm: model})
           |> LLMChain.add_messages(@messages)
           |> LLMChain.add_message(
             Message.new_user!(
               ~s"Translate the following #{type_context} into #{@language[language]}:

      #{text}"
             )
           )
           |> LLMChain.run(mode: :until_success),
         %LangChain.Message{
           content: [%LangChain.Message.ContentPart{type: :text, content: content}]
         } = chain.last_message do
      {:ok, content}
    else
      {:error, _, %LangChain.LangChainError{message: message}} ->
        {:error, "Unable to translate using LLM: #{message}"}
    end
  end
end
