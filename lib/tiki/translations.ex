defmodule Tiki.Translations do
  use Gettext, backend: TikiWeb.Gettext

  @model "openai:gpt-5.4-nano"

  @system_prompt ~s"You are a professional translation assistant for an event hosting platform.
  Your task is to translate event-related content (titles, descriptions, form questions.) between English and Swedish.

  Guidelines:
  - Provide only the translated text, without explanations or commentary.
  - Maintain the original meaning and tone: concise, clear, and suitable for an event listing.
  - Do not add, omit, or infer information. Translate what is given, nothing more.
  - Keep formatting, capitalization, emojis, punctuation, and special characters intact.
  - For short phrases like event titles, keep the style natural in the target language.
  - If the text is already in the target language, return it unchanged.
  - Do not use em dashes or other -isms that are common for LLMs."

  @language %{"sv" => "Swedish", "en" => "English"}

  def generate_translation("", _, _) do
    {:error, gettext("Please provide an input text to translate first.")}
  end

  def generate_translation(nil, _, _) do
    {:error, gettext("Please provide an input text to translate first.")}
  end

  # needs
  def generate_translation(text, language, type_context) do
    with {:ok, response} <-
           ReqLLM.generate_text(
             @model,
             ~s"Translate the following #{type_context} into #{@language[language]}:

#{text}",
             system_prompt: @system_prompt,
             reasoning_effort: :low
           ) do
      {:ok, ReqLLM.Response.text(response)}
    end
  end
end
