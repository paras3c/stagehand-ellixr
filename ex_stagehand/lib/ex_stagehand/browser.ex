defmodule ExStagehand.Browser do
  use GenServer
  require Logger

  defstruct [:port, :ws_url, :cdp_pid, :chrome_port, :user_data_dir, :mode]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_ws_url(pid \\ __MODULE__) do
    GenServer.call(pid, :get_ws_url)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    if opts[:connect_url] do
       init_remote(opts[:connect_url])
    else
       init_local(opts)
    end
  end
  
  defp init_remote(ws_url) do
    Logger.info("Connecting to Remote Browser at #{ws_url}")
    {:ok, %__MODULE__{ws_url: ws_url, mode: :remote}}
  end

  defp init_local(opts) do
    chrome_path = find_chrome_executable()
    user_data_dir = create_temp_dir()
    port = opts[:port] || 9222

    args = [
      "--remote-debugging-port=#{port}",
      "--no-first-run",
      "--no-default-browser-check",
      "--user-data-dir=#{user_data_dir}",
      "--headless=new", # Optional: make configurable
      "--disable-gpu",
      "--remote-allow-origins=*"
    ]

    Logger.info("Launching Chrome from #{chrome_path} on port #{port}...")
    
    # Launch Chrome as a Port
    chrome_port = Port.open({:spawn_executable, chrome_path}, [:binary, :exit_status, args: args])
    
    # Wait for Chrome to come up and get the WebSocket URL
    ws_url = wait_for_cdp_endpoint(port)

    {:ok, %__MODULE__{port: port, ws_url: ws_url, chrome_port: chrome_port, user_data_dir: user_data_dir, mode: :local}}
  end

  @impl true
  def handle_call(:get_ws_url, _from, state) do
    {:reply, state.ws_url, state}
  end
  
  @impl true
  def handle_info({port, {:exit_status, status}}, state) when port == state.chrome_port do
    Logger.warning("Chrome exited with status: #{status}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
     Logger.info("Cleaning up Browser...")
     if state.mode == :local and state.user_data_dir do
        File.rm_rf(state.user_data_dir)
     end
     :ok
  end

  # Helpers

  defp find_chrome_executable do
    [
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
      "/usr/bin/google-chrome" # Linux fallback
    ]
    |> Enum.find(&File.exists?/1)
    |> case do
      nil -> raise "Could not find Chrome executable"
      path -> path
    end
  end

  defp create_temp_dir do
    dir = Path.join(System.tmp_dir!(), "ex_stagehand_#{UUID.uuid4()}")
    File.mkdir_p!(dir)
    dir
  end

  defp wait_for_cdp_endpoint(port, retries \\ 10) do
    url = "http://localhost:#{port}/json/version"
    
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        body["webSocketDebuggerUrl"]
      _ ->
        if retries > 0 do
          Process.sleep(500)
          wait_for_cdp_endpoint(port, retries - 1)
        else
          raise "Failed to connect to Chrome CDP on port #{port}"
        end
    end
  end
end
