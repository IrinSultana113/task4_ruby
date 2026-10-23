
class ChatsController < ApplicationController
  before_action :ensure_authenticated_and_active!

SYSTEM_PROMPT = <<~PROMPT.freeze
  You are a user management assistant.
  Always call tools before answering any question about users or counts.
  Never invent numbers, names, emails, statuses, or other user data.
  Base every answer only on tool results.
  Never reveal passwords or password digests.
  Answer concisely in English.
  Do not mention system limits or suggest extra filters.
PROMPT

  ALLOWED_TOOLS = %w[
    get_user_counts
    get_users
    count_users_by_job_position
  ].freeze

  TOOLS = [
    {
      type: "function",
      function: {
        name: "get_user_counts",
        description: "Get exact total, active and blocked user counts.",
        parameters: {
          type: "object",
          properties: {},
          required: [],
          additionalProperties: false
        }
      }
    },
    {
      type: "function",
      function: {
        name: "get_users",
        description: "Search users by status, email prefix, job position, name or recent activity. Returns at most 100 safe user records and the total matching count.",
        parameters: {
          type: "object",
          properties: {
            status: {
              type: "string",
              enum: ["active", "blocked"],
              description: "Optional status filter"
            },
            email_prefix: {
              type: "string",
              description: "Optional email prefix, for example s or p"
            },
            job_position: {
              type: "string",
              description: "Optional job position text"
            },
            name: {
              type: "string",
              description: "Search users by full name"
            },
            last_seen_hours: {
              type: "integer",
              minimum: 1,
              maximum: 8760,
              description: "Only users whose last_seen is within this many hours"
            }
          },
          required: [],
          additionalProperties: false
        }
      }
    },
    {
      type: "function",
      function: {
        name: "count_users_by_job_position",
        description: "Get exact user counts grouped by job position.",
        parameters: {
          type: "object",
          properties: {},
          required: [],
          additionalProperties: false
        }
      }
    }
  ].freeze

  def show
    @question = ""
    @answer = nil
    render template: "chats/show"
  end

  def create
    @question = params[:question].to_s.strip

    if @question.blank?
      @answer = "Please enter a question."
      render :show, status: :unprocessable_entity
      return
    end

    if @question.length > 1000
      @answer = "Please keep your question under 1000 characters."
      render :show, status: :unprocessable_entity
      return
    end

    @answer = answer_question(@question)
    render template: "chats/show"

  rescue StandardError => e
    Rails.logger.error("Chat error: #{e.class}: #{e.message}")
    @answer = "Sorry, I couldn't process that question. Please try again."
    render :show, status: :service_unavailable
  end

  private

  def answer_question(question)
    client = OpenRouterService.new

    messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: question }
    ]

    used_tools = false

    # Limit tool-call rounds to prevent endless loops.
    3.times do
      # Force a tool call until we have real database results.
      tool_choice = used_tools ? "auto" : "required"
      result = client.chat(messages: messages, tools: TOOLS, tool_choice: tool_choice)
      message = result.dig("choices", 0, "message")

      raise "Missing assistant message" unless message

      tool_calls = message["tool_calls"]

      unless tool_calls.present?
        # Only accept a text answer after tools have returned data.
        if used_tools
          return message["content"].presence ||
            "I couldn't produce an answer. Please try rephrasing."
        end

        raise "Model answered without querying the database"
      end

      # Preserve the assistant's original tool-call message.
      messages << message

      tool_calls.each do |tool_call|
        function = tool_call.dig("function", "name")
        raw_arguments = tool_call.dig("function", "arguments")

        # Only execute explicitly allowlisted functions.
        unless ALLOWED_TOOLS.include?(function)
          raise "Unsupported tool requested"
        end

        arguments = JSON.parse(raw_arguments.presence || "{}")
        data = UserDataService.call(function, arguments)

        messages << {
          role: "tool",
          tool_call_id: tool_call.fetch("id"),
          content: JSON.generate(data)
        }
      end

      used_tools = true
    end

    raise "No database results were available for this question" unless used_tools

    # One final request without tools after the tool-call limit.
    final_result = client.chat(messages: messages, tools: nil)
    final_result.dig("choices", 0, "message", "content").presence ||
      "I couldn't complete the answer. Please try a simpler question."
  end
end
