# ExStagehand

ExStagehand is an Elixir implementation of the Stagehand browser automation framework, designed to work seamlessly with **Browserbase**. It provides a native interface for controlling Chrome browsers using natural language instructions and structured data extraction, powered by the Actor Model for high concurrency.

## Overview

This library enables developers to automate browser interactions through a high-level API that bridges the gap between code and AI. By leveraging Large Language Models (LLMs) and **Browserbase's infrastructure**, ExStagehand allows for scalable, fault-tolerant browser automation directly from the BEAM.

## Features

*   **AI-Driven Action**: Execute browser actions using natural language instructions (e.g., "Click the login button").
*   **Browserbase Ready**: Seamlessly connects to Browserbase's cloud infrastructure for scalable, remote browser sessions without local overhead.
*   **Structured Extraction**: Extract data from web pages into Elixir maps based on provided schemas.
*   **Intelligent Observation**: Analyze page content to identify interactive elements and capabilities.
*   **Native Architecture**: Built on OTP (Open Telecom Platform) using GenServers for robust process management.
*   **Direct CDP Integration**: Connects directly to the Chrome DevTools Protocol via WebSockets, eliminating the need for intermediate Node.js services.

## Architecture

The system is composed of the following core components:

*   **Browser**: A GenServer responsible for managing the connection to the browser (supports both Local Chrome and **Remote Browserbase Sessions**).
*   **Page**: A GenServer representing an individual browser tab, utilizing CDP Sessions to multiplex commands over a single WebSocket connection.
*   **LLM**: A module handling interactions with AI providers (currently supporting OpenAI) for instruction parsing.

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

*   `OPENAI_API_KEY` environment variable configured.
*   **Option A (Cloud)**: A [Browserbase](https://browserbase.com) API Key and Project ID.
*   **Option B (Local)**: Google Chrome installed on the host machine.

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
