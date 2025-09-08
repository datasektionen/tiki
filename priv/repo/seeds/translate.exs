alias LangChain.Chains.LLMChain
alias LangChain.ChatModels.ChatOpenAI
alias LangChain.Message
alias LangChain.Function



messages = [
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


list_events = Function.new!(%{
  name: "list_events",
  description: "List all events in the database",
  function: fn _args, _context ->
    {:ok, Tiki.Events.list_events()}
  end}
)


update_event = Function.new!(%{
name: "update_event",
description: "Update an event in the database, given its ID. Only the fields that are provided will be updated, the rest will be left unchanged.
Params must be supplied in valid JSON. The event ID is a uuid.",
function: fn %{"event_id" => id, "params" => params}, _context ->
  with {:ok, event_params} <- Jason.decode(params),
       event <- Tiki.Events.get_event!(id) do
         Tiki.Events.update_event(event, params)
       end
end})


model =
  ChatOpenAI.new!(%{
    reasoning: false,
    reasoning_effort: "minimal",
    model: "gpt-4o-mini-2024-07-18",
    stream: false
  })


result = LLMChain.new!(%{llm: model})
|> LLMChain.add_messages(messages)
|> LLMChain.add_message(
  Message.new_user!(
    ~s"Look up the events in the database, and return them as a JSON array."
    ))
    |> LLMChain.add_tools([list_events])
    |> LLMChain.run(mode: :until_success)


dbg(result)
