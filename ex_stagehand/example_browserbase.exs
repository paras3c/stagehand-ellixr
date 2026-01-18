# Example: Connecting to Browserbase
# 
# Usage:
#   export BROWSERBASE_PROJECT_ID="your_project_id"
#   export BROWSERBASE_API_KEY="your_api_key"
#   export OPENAI_API_KEY="your_openai_key"
#   mix run example_browserbase.exs

require Logger

# 1. Start the HTTP/WebSocket clients
Application.ensure_all_started(:req)
Application.ensure_all_started(:websockex)
Application.ensure_all_started(:ex_stagehand)

# 2. Configure Browserbase
project_id = System.get_env("BROWSERBASE_PROJECT_ID")
api_key = System.get_env("BROWSERBASE_API_KEY")

if is_nil(project_id) or is_nil(api_key) do
  Logger.error("Please set BROWSERBASE_PROJECT_ID and BROWSERBASE_API_KEY environment variables.")
  System.halt(1)
end

# Browserbase Connect URL (Standard format)
# We use the generic connect URL which typically looks like:
# wss://connect.browserbase.com?apiKey=...&projectId=...
connect_url = "wss://connect.browserbase.com?apiKey=#{api_key}&projectId=#{project_id}"

Logger.info("Starting ExStagehand with Browserbase...")

# 3. Connect to Remote Browser
{:ok, browser} = ExStagehand.Browser.start_link(connect_url: connect_url)

# 4. Create a Page (Tab)
{:ok, page} = ExStagehand.Page.start_link(browser)

# 5. Navigate
Logger.info("Navigating to GitHub...")
ExStagehand.Page.goto(page, "https://github.com/browserbase")

# 6. Act
Logger.info("Finding Stagehand repo...")
# Note: This uses AI to find the link
ExStagehand.Page.act(page, "Click on the stagehand repository")

# 7. Extract
Logger.info("Extracting details...")
data = ExStagehand.Page.extract(page, "Get the repository description and star count", %{
  description: "string",
  stars: "string"
})

IO.inspect(data, label: "Extracted Data")

# Keep the process alive for a moment to see results
Process.sleep(5000)
