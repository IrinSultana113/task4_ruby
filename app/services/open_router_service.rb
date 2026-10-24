
require "json"

class OpenRouterService
  URL = "https://openrouter.ai/api/v1/chat/completions"

  def initialize
    @connection = Faraday.new do |f|
      f.options.timeout = 45
      f.options.open_timeout = 10
      f.adapter :net_http
    end
  end

  def chat(messages:, tools: nil, tool_choice: "auto")
    api_key = ENV["OPENROUTER_API_KEY"]

    raise "Missing OPENROUTER_API_KEY in .env" if api_key.blank?

    payload = {
      model: ENV.fetch("OPENROUTER_MODEL", "recursive/flint-v1.0:free"),
      messages: messages,
      temperature: 0,
      max_tokens: 1000
    }

    if tools
      payload[:tools] = tools
      payload[:tool_choice] = tool_choice
    end

    response = @connection.post(URL) do |request|
      request.headers["Authorization"] = "Bearer #{api_key.strip}"
      request.headers["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
    end 

    unless response.success?
      Rails.logger.error("OpenRouter HTTP #{response.status}: #{response.body}")
      raise "OpenRouter request failed (HTTP #{response.status})"
    end

    body = JSON.parse(response.body)

    puts "\n========== OpenRouter API Response =========="
    puts JSON.pretty_generate(body)
    Rails.logger.info("OpenRouter selected model: #{body["model"]}")
    puts "=============================================\n"

    unless body.dig("choices", 0, "message")
      Rails.logger.error("OpenRouter response: #{response.body}")
    end

    body
  end
end
