defmodule ExStagehand.LLM do
  require Logger

  def chat_completion(prompt, opts \\ []) do
    model = opts[:model] || "gpt-3.5-turbo"
    json_mode = opts[:json] || false
    
    api_key = System.get_env("OPENAI_API_KEY") # || raise "OPENAI_API_KEY is missing"
    
    # Mock return if no key for basic testing
    if is_nil(api_key) do
      Logger.warning("No OPENAI_API_KEY found. using mock response.")
      if json_mode do
         {:ok, %{"extracted_data" => "Mock Data", "elements" => [%{"selector" => "button", "description" => "Submit"}]}}
      else
         {:ok, "document.querySelector('a').click()"}
      end
    else
        headers = [
          {"Authorization", "Bearer #{api_key}"},
          {"Content-Type", "application/json"}
        ]
        
        response_format = if json_mode, do: %{type: "json_object"}, else: nil
        
        system_msg = if json_mode do
           "You are a browser automation assistant. You strictly return JSON."
        else
           "You are a browser automation assistant. Return a valid CSS selector or Javascript code to perform the user's action."
        end
    
        body = %{
          model: model,
          messages: [
            %{role: "system", content: system_msg},
            %{role: "user", content: prompt}
          ],
          response_format: response_format
        }
        # Remove nil fields
        body =  Map.reject(body, fn {_, v} -> is_nil(v) end)
    
        case Req.post("https://api.openai.com/v1/chat/completions", json: body, headers: headers) do
          {:ok, %{status: 200, body: body}} ->
             choice = List.first(body["choices"])
             content = choice["message"]["content"]
             
             if json_mode do
                case Jason.decode(content) do
                  {:ok, decoded} -> {:ok, decoded}
                  {:error, _} -> 
                     Logger.warning("LLM returned invalid JSON: #{content}")
                     {:error, :invalid_json}
                end
             else
                {:ok, content}
             end
          {:ok, response} ->
             Logger.error("LLM Error: #{inspect(response)}")
             {:error, response}
          {:error, reason} ->
             {:error, reason}
        end
    end
  end
end
