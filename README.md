# ExStagehand

ExStagehand is an Elixir implementation of the Stagehand browser automation framework. It provides a native interface for controlling Chrome browsers using natural language instructions and structured data extraction, powered by the Actor Model for concurrency and fault tolerance.

## Overview

This library enables developers to automate browser interactions through a high-level API that bridges the gap between code and AI. By leveraging Large Language Models (LLMs), ExStagehand can interpret natural language commands to perform actions on web pages and extract data according to defined schemas.

## Features

*   **AI-Driven Action**: Execute browser actions using natural language instructions (e.g., "Click the login button").
*   **Structured Extraction**: Extract data from web pages into Elixir maps based on provided schemas.
*   **Intelligent Observation**: Analyze page content to identify interactive elements and capabilities.
*   **Native Architecture**: Built on OTP (Open Telecom Platform) using GenServers for robust process management.
*   **Direct CDP Integration**: Connects directly to the Chrome DevTools Protocol via WebSockets, eliminating the need for intermediate Node.js services.

## Architecture

The system is composed of the following core components:

*   **Browser**: A GenServer responsible for managing the operating system process for the Chrome browser.
*   **Page**: A GenServer representing an individual browser tab, managing independent WebSocket connections for CDP interactions.
*   **LLM**: A module handling interactions with AI providers (currently supporting OpenAI) for instruction parsing and inference.

## Installation

To install ExStagehand, add the dependency to your `mix.exs` file:

```elixir
def deps do
  [
    {:ex_stagehand, path: "./path/to/ex_stagehand"}
  ]
end
```

Then, fetch the dependencies:

```bash
mix deps.get
```

### Prerequisites

*   Google Chrome installed on the host machine.
*   `OPENAI_API_KEY` environment variable configured.

## Usage

### Launching the Browser
 
 **Local Chrome:**
 
 ```elixir
 {:ok, browser} = ExStagehand.Browser.start_link()
 ```
 
 **Remote Browser (e.g. Browserbase):**
 
 ```elixir
 connect_url = "wss://connect.browserbase.com?apiKey=YOUR_KEY&projectId=YOUR_ID"
 {:ok, browser} = ExStagehand.Browser.start_link(connect_url: connect_url)
 ```
 
 ### Navigating and Acting
 
 ```elixir
 {:ok, page} = ExStagehand.Page.start_link(browser)
 ExStagehand.Page.goto(page, "https://example.com")
 
 # Perform an action using natural language
 ExStagehand.Page.act(page, "Click on the 'More Information' link")
 ```

### Data Extraction

To extract data, provide a description of the desired data and a schema definition:

```elixir
data = ExStagehand.Page.extract(page, "Details about the article", %{
  title: "string",
  author: "string",
  date: "string"
})
```

## License

This project is licensed under the MIT License.
