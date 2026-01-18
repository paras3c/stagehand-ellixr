# example.exs
# Run with: mix run example.exs

require Logger

Logger.info("Starting Browser...")
{:ok, browser} = ExStagehand.Browser.start_link()

Logger.info("Creating Page...")
{:ok, page} = ExStagehand.Page.start_link(browser)

Logger.info("Navigating to https://example.com...")
ExStagehand.Page.goto(page, "https://example.com")

Logger.info("Waiting for page load...")
Process.sleep(2000)

Logger.info("Acting: Click on the 'More information' link...")
result = ExStagehand.Page.act(page, "Click on the 'More information' link")

Logger.info("Result: #{inspect(result)}")

Logger.info("Extracting: Getting page title and main link...")
data = ExStagehand.Page.extract(page, "extract the page title and main link", %{
  title: "string",
  link: "string"
})
Logger.info("Extracted Data: #{inspect(data)}")

Logger.info("Observing: Finding interactive elements...")
elements = ExStagehand.Page.observe(page, "what can I click here?")
Logger.info("Observed Elements: #{inspect(elements)}")

Logger.info("Done. Sleeping for 5s before exit.")
Process.sleep(5000)
