defmodule ExStagehand.CDP do
  use WebSockex
  require Logger

  defstruct [:callbacks, :event_subscribers]

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{callbacks: %{}, event_subscribers: []})
  end

  def execute(pid, method, params \\ %{}, opts \\ []) do
    id = get_next_id()
    request = %{
      id: id,
      method: method,
      params: params
    }
    
    request = if opts[:session_id], do: Map.put(request, :sessionId, opts[:session_id]), else: request

    
    ref = make_ref()
    caller = self()
    
    WebSockex.cast(pid, {:send_request, request, id, caller, ref})
    
    receive do
      {:cdp_reply, ^ref, response} -> response
    after
      30_000 -> 
          # Cleanup the callback to prevent memory leak
          WebSockex.cast(pid, {:remove_callback, id})
          {:error, :timeout}
    end
  end

  # Helpers
  
  defp get_next_id do
    System.unique_integer([:positive, :monotonic])
  end

  # Callbacks

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to CDP")
    {:ok, state}
  end

  @impl true
  def handle_cast({:remove_callback, id}, state) do
     new_callbacks = Map.delete(state.callbacks, id)
     {:ok, %{state | callbacks: new_callbacks}}
  end      
          
  @impl true
  def handle_cast({:send_request, request, id, caller, ref}, state) do
    new_callbacks = Map.put(state.callbacks, id, {caller, ref})
    json = Jason.encode!(request)
    {:reply, {:text, json}, %{state | callbacks: new_callbacks}}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    data = Jason.decode!(msg)
    
    id = data["id"]
    method = data["method"]
    
    # Check if it is a response to a request
    state = if id do
      case Map.pop(state.callbacks, id) do
        {{caller, ref}, new_callbacks} ->
          send(caller, {:cdp_reply, ref, data})
          %{state | callbacks: new_callbacks}
        {nil, _} ->
          state
      end
    else
      # It's an event
      if method do
        # Logger.debug("CDP Event: #{method}")
        # Dispatch to subscribers (TODO)
      end
      state
    end

    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("CDP Disconnected: #{inspect(reason)}")
    {:ok, state}
  end
end
