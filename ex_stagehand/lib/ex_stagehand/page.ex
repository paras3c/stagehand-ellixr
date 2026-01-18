defmodule ExStagehand.Page do
  use GenServer
  require Logger
  alias ExStagehand.{Browser, CDP}

  defstruct [:browser_cdp, :page_cdp, :target_id]

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
    {:ok, browser_cdp} = CDP.start_link(ws_url)
    
    # 3. Create new Target (Page)
    response = CDP.execute(browser_cdp, "Target.createTarget", %{"url" => "about:blank"})
    target_id = response["result"]["targetId"]
    
    # 4. Get the WebSocket URL for this specific target
    # We can ask the browser for the list of targets via HTTP to find the WS URL for this ID
    # OR we can attach via CDP.
    # The HTTP endpoint /json is easier to parse for the WS URL.
    
    # Extract port from ws_url
    uri = URI.parse(ws_url)
    port = uri.port
    
    page_ws_url = get_target_ws_url(port, target_id)
    
    # 5. Connect to Page
    {:ok, page_cdp} = CDP.start_link(page_ws_url)
    
    # 6. Enable Page/Runtime domains
    CDP.execute(page_cdp, "Page.enable")
    CDP.execute(page_cdp, "Runtime.enable")
    CDP.execute(page_cdp, "DOM.enable")

    {:ok, %__MODULE__{browser_cdp: browser_cdp, page_cdp: page_cdp, target_id: target_id}}
  end

  @impl true
  def handle_call({:goto, url}, _from, state) do
    response = CDP.execute(state.page_cdp, "Page.navigate", %{"url" => url})
    # TODO: Wait for load event (Page.loadEventFired)
    # For now, just sleep briefly or rely on the response
    Process.sleep(1000) 
    {:reply, response, state}
  end
  
  @impl true
  def handle_call(:get_content, _from, state) do
    # Get document root
    %{ "result" => %{ "root" => root } }  = CDP.execute(state.page_cdp, "DOM.getDocument", %{"depth" => -1})
    root_node_id = root["nodeId"]
    
    # Get Outer HTML
    %{ "result" => %{ "outerHTML" => html } } = CDP.execute(state.page_cdp, "DOM.getOuterHTML", %{"nodeId" => root_node_id})
    
    {:reply, html, state}
  end

  @impl true
  def handle_call({:act, instruction}, _from, state) do
    # 1. Get current page state (simplified HTML) via Runtime.evaluate to avoid stale node IDs
    %{ "result" => %{ "result" => %{ "value" => html } } } = CDP.execute(state.page_cdp, "Runtime.evaluate", %{"expression" => "document.documentElement.outerHTML"})

    # 2. Ask LLM what to do
    # We truncate HTML for token limits in this MVP
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
    
    # We await the promise to ensure it resolves?
    # Runtime.evaluate has awaitPromise: true
    result = CDP.execute(state.page_cdp, "Runtime.evaluate", %{
      "expression" => script,
      "awaitPromise" => true,
      "returnByValue" => true
    })
    
    case result do
      %{"result" => %{"type" => "string", "value" => _}} -> 
          # Assuming successful execution returns something or we just check exceptionDetails
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
     # 1. Get DOM via Runtime.evaluate
    %{ "result" => %{ "result" => %{ "value" => html } } } = CDP.execute(state.page_cdp, "Runtime.evaluate", %{"expression" => "document.documentElement.outerHTML"})
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
     # 1. Get DOM - Just use -1 depth to get the whole tree for now, creating new node IDs
     # We might need to call requestChildNodes if getDocument doesn't return everything deep enough?
     # Actually, let's just use evaluate to get document.documentElement.outerHTML directly to avoid NodeId issues.
    
    %{ "result" => %{ "result" => %{ "value" => html } } } = CDP.execute(state.page_cdp, "Runtime.evaluate", %{"expression" => "document.documentElement.outerHTML"})
    
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

  defp get_target_ws_url(port, target_id) do
    url = "http://localhost:#{port}/json"
    {:ok, %{body: targets}} = Req.get(url)
    
    target = Enum.find(targets, fn t -> t["id"] == target_id end)
    target["webSocketDebuggerUrl"]
  end
end
