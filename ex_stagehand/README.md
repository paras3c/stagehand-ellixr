# ExStagehand: The AI Browser Agent for Elixir (Unofficial)

**ExStagehand** is an **unofficial** Elixir implementation of the [Stagehand](https://stagehand.dev) framework. It brings the power of AI-driven browser automation to the BEAM, allowing you to control Chrome using natural language and structured data extraction, all managed by robust supervision trees.

> [!WARNING]
> **This is a community project and is NOT affiliated with or supported by Browserbase.**
> Please do not contact Browserbase support for issues related to this SDK. Open issues in this repository instead.

## Features

- **🤖 AI-Driven Navigation**: Use `Page.act/2` to click, type, and navigate using plain English instructions.
- **📊 Structured Extraction**: Use `Page.extract/3` to scrape data into clean Elixir maps using JSON schemas.
- **👀 Intelligent Observation**: Use `Page.observe/2` to identify interactive elements on the page capabilities.
- **⚡️ Elixir Native**: built on the Actor Model. Each Browser and Page is a separate GenServer, making your automation fault-tolerant and concurrent.
- **🌐 Direct CDP**: Connects directly to Chrome via WebSockets—no Node.js or Playwright sidecar required.

## Installation

1.  **Add to `mix.exs`:**

    ```elixir
    def deps do
      [
        {:ex_stagehand, path: "./path/to/ex_stagehand"} # Currently local only
      ]
    end
    ```

2.  **Install Dependencies:**

    ```bash
    mix deps.get
    ```

3.  **Prerequisites:**
    - Google Chrome installed on your machine.
    - `OPENAI_API_KEY` environment variable set (for AI features).

## Usage

### 1. Launch & Navigate

```elixir
# Start the browser process (launches Headless Chrome)
{:ok, browser} = ExStagehand.Browser.start_link()

# Open a new tab (Page)
{:ok, page} = ExStagehand.Page.start_link(browser)

# Go to a URL
ExStagehand.Page.goto(page, "https://news.ycombinator.com")
```

### 2. Act (Do things)

Tell the browser what to do in natural language.

```elixir
# Click the first link
ExStagehand.Page.act(page, "Click on the first story link")
```

### 3. Extract (Get data)

Get structured data back. Define your schema as a simple Map.

```elixir
data = ExStagehand.Page.extract(page, "Details about the story", %{
  title: "string",
  points: "number",
  author: "string"
})

IO.inspect(data)
# => %{"title" => "Elixir is great", "points" => 100, "author" => "josevalim"}
```

### 4. Observe (See what's possible)

Ask the agent what it sees or what is interactive.

```elixir
elements = ExStagehand.Page.observe(page, "What are the main navigation links?")

IO.inspect(elements)
# => %{"elements" => [%{"selector" => "a#new", "description" => "New Submissions"}]}
```

## Architecture

ExStagehand leverages Elixir's OTP:

*   **`ExStagehand.Browser`**: A GenServer that owns the OS process for Chrome. If it crashes, it can restart Chrome (implementation pending).
*   **`ExStagehand.Page`**: A GenServer representing a single Tab. It manages its own WebSocket connection to the Chrome DevTools Protocol (CDP).
*   **`ExStagehand.LLM`**: Handles AI inference. Currently supports OpenAI.

## Roadmap

This is a proof-of-concept. Future improvements include:

- [ ] **Accessibility Tree**: Reduce token usage by sending a simplified AXTree instead of raw HTML.
- [ ] **Vision Support**: Send screenshots to GPT-4o for better understanding.
- [ ] **Browserbase Integration**: Connect to remote Browserbase sessions instead of local Chrome.
- [ ] **Multi-provider Support**: Support Anthropic/Claude.

## License

MIT
