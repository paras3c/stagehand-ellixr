defmodule ExStagehand.Page do
  use GenServer
  require Logger
  alias ExStagehand.{Browser, CDP}

  defstruct [:browser_cdp, :session_id, :target_id]

  def start_link(browser_pid) do
    GenServer.start_link(__MODULE__, browser_pid)
  end

  def goto(pid, url) do
    GenServer.call(pid, {:goto, url})
  end
  
  def content(pid) do
    GenServer.call(pid, :get_content)
  end
  
  def act(pid, instruction) do
    GenServer.call(pid, {:act, instruction}, 60_000)
  end

  def extract(pid, instruction, schema) do
    GenServer.call(pid, {:extract, instruction, schema}, 60_000)
  end

  def observe(pid, instruction \\ nil) do
    GenServer.call(pid, {:observe, instruction}, 60_000)
  end

  # Callbacks

  @impl true
  def init(browser_server_pid) do
    # 1. Get Browser WS URL
    ws_url = Browser.get_ws_url(browser_server_pid)
    
    # 2. Connect to Browser (Main Connection)
    # Note: In a real app we might want to share this connection process instead of making a new one per page-process
    {:ok, browser_cdp} = CDP.start_link(ws_url)
    
    # 3. Create new Target (Page)
    response = CDP.execute(browser_cdp, "Target.createTarget", %{"url" => "about:blank"})
    target_id = response["result"]["targetId"]
    
    # 4. Attach to Target to get Session ID (This works for Local AND Remote)
    response = CDP.execute(browser_cdp, "Target.attachToTarget", %{"targetId" => target_id, "flatten" => true})
    session_id = response["result"]["sessionId"]
    
    # 5. Enable Page/Runtime domains VIA SESSION
    execute_cdp(browser_cdp, session_id, "Page.enable")
    execute_cdp(browser_cdp, session_id, "Runtime.enable")
    execute_cdp(browser_cdp, session_id, "DOM.enable")

    {:ok, %__MODULE__{browser_cdp: browser_cdp, session_id: session_id, target_id: target_id}}
  end

  @impl true
  def handle_call({:goto, url}, _from, state) do
    response = execute_cdp(state.browser_cdp, state.session_id, "Page.navigate", %{"url" => url})
    # TODO: Wait for load event
    Process.sleep(1000) 
    {:reply, response, state}
  end
  
  @impl true
  def handle_call(:get_content, _from, state) do
    # Get document root
    %{ "result" => %{ "root" => root } }  = execute_cdp(state.browser_cdp, state.session_id, "DOM.getDocument", %{"depth" => -1})
    root_node_id = root["nodeId"]
    
    # Get Outer HTML
    %{ "result" => %{ "outerHTML" => html } } = execute_cdp(state.browser_cdp, state.session_id, "DOM.getOuterHTML", %{"nodeId" => root_node_id})
    
    {:reply, html, state}
  end

  @impl true
  def handle_call({:act, instruction}, _from, state) do
    # 1. Get DOM
    %{ "result" => %{ "result" => %{ "value" => html } } } = execute_cdp(state.browser_cdp, state.session_id, "Runtime.evaluate", %{"expression" => "document.documentElement.outerHTML"})

    # 2. Ask LLM
    html_sample = String.slice(html, 0, 10000) 
    prompt = """
    I have this HTML:
    #{html_sample}
    ...
    
    User wants to: #{instruction}
    
    Return ONLY a Javascript snippet to execute on this page to accomplish the task. 
    Do not use markdown blocks. Just the code.
    Example: document.querySelector('button').click()
    """
    
    {:ok, script} = ExStagehand.LLM.chat_completion(prompt)
    
    # Remove markdown code blocks if present
    script = 
      case Regex.run(~r/```(?:javascript|js)?\s*(.*)\s*```/s, script) do
        [_, code] -> String.trim(code)
        nil -> String.trim(script, "`") # Fallback to removing backticks
      end
    
    Logger.info("Executing AI Script: #{script}")
    
    # 3. Execute Script
    result = execute_cdp(state.browser_cdp, state.session_id, "Runtime.evaluate", %{
      "expression" => script,
      "awaitPromise" => true,
      "returnByValue" => true
    })
    
    case result do
      %{"result" => %{"type" => "string", "value" => _}} -> 
          {:reply, result, state}
      %{"exceptionDetails" => details} ->
          Logger.error("Action Failed via JS Exception: #{inspect(details)}")
          {:reply, {:error, :js_exception, details}, state}
       _ ->
          if result["exceptionDetails"] do
             Logger.error("Action Failed via JS Exception: #{inspect(result["exceptionDetails"])}")
             {:reply, {:error, :js_exception, result["exceptionDetails"]}, state}
          else
             {:reply, result, state}
          end
    end
  end

  @impl true
  def handle_call({:extract, instruction, schema}, _from, state) do
     # 1. Get DOM
    %{ "result" => %{ "result" => %{ "value" => html } } } = execute_cdp(state.browser_cdp, state.session_id, "Runtime.evaluate", %{"expression" => "document.documentElement.outerHTML"})
    html_sample = String.slice(html, 0, 10000) 
    
    # 2. Build Prompt
    prompt = """
    Extract data from this HTML:
    #{html_sample}
    ...
    
    Instruction: #{instruction}
    
    Return JSON matching this schema:
    #{Jason.encode!(schema)}
    """
    
    # 3. Call LLM with JSON mode
    {:ok, data} = ExStagehand.LLM.chat_completion(prompt, json: true)
    
    {:reply, data, state}
  end

  @impl true
  def handle_call({:observe, instruction}, _from, state) do
    # 1. Get DOM
    %{ "result" => %{ "result" => %{ "value" => html } } } = execute_cdp(state.browser_cdp, state.session_id, "Runtime.evaluate", %{"expression" => "document.documentElement.outerHTML"})
    
    html_sample = String.slice(html, 0, 10000) 
    
    # 2. Build Prompt
    instruction_text = if instruction, do: "Focus on elements related to: #{instruction}", else: "Find all key interactive elements."
    
    prompt = """
    Analyze this HTML:
    #{html_sample}
    ...
    
    #{instruction_text}
    
    Return JSON with a list of interactive elements.
    Schema:
    {
      "elements": [
        { "selector": "css_selector", "description": "what this does" }
      ]
    }
    """
    
    # 3. Call LLM with JSON mode
    {:ok, data} = ExStagehand.LLM.chat_completion(prompt, json: true)
    
    {:reply, data, state}
  end

  defp execute_cdp(pid, session_id, method, params \\ %{}) do
    CDP.execute(pid, method, params, session_id: session_id)
  end
end
