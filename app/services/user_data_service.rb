
class UserDataService
  SAFE_FIELDS = %w[full_name email job_position status last_seen].freeze

  def self.call(name, arguments)
    case name
    when "get_user_counts"
      {
        total: User.count,
        active: User.where(status: "active").count,
        blocked: User.where(status: "blocked").count
      }
    when "get_users"
      get_users(arguments)
    when "count_users_by_job_position"
      User.group(:job_position).count
    else
      raise ArgumentError, "Unknown tool: #{name}"
    end
  end

  def self.get_users(arguments)
    scope = User.all

    user_name = arguments["name"].to_s.strip
    if user_name.present?
      scope = scope.where("full_name LIKE ?", "%#{user_name}%")
    end

    status = arguments["status"].to_s
    scope = scope.where(status: status) if %w[active blocked].include?(status)

    position = arguments["job_position"].to_s.strip
    if position.present?
      scope = scope.where("job_position LIKE ?", "%#{position}%")
    end

    prefix = arguments["email_prefix"].to_s.downcase.strip
    if prefix.present?
      unless prefix.match?(/\A[a-z0-9._%+\-]+\z/i)
        raise ArgumentError, "Invalid email prefix"
      end

      prefixes = prefix.split(/\s+or\s+/i)
      conditions = prefixes.map { "LOWER(email) LIKE ?" }.join(" OR ")
      scope = scope.where(conditions, *prefixes.map { |p| "#{p}%" })
    end

    hours = arguments["last_seen_hours"]
    if hours.present?
      hours = Integer(hours)
      raise ArgumentError, "Invalid time range" unless (1..8760).cover?(hours)

      scope = scope.where("last_seen >= ?", hours.hours.ago)
    end

    total = scope.count
    rows = scope.order(last_seen: :desc).limit(100)

    {
      count: total,
      users: rows.map { |user| user.attributes.slice(*SAFE_FIELDS) },
      limited: total > 100
    }
  end

  private_class_method :get_users
end
