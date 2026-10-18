require 'json'

file_path = Rails.root.join('db', 'users.json')

if File.exist?(file_path)
  file = File.read(file_path)
  users_data = JSON.parse(file)

  users_data.each do |user_data|
    user = User.find_by(email: user_data['email']) || User.new(email: user_data['email'])
    user.full_name = user_data['full_name']
    user.job_position = user_data['job_position']
    user.last_seen = user_data['last_seen']
    user.status = user_data['status'] || 'active'
    user.password = 'password'          # Default password for all JSON users
    user.password_confirmation = 'password'
    user.save!
  end
  puts "Successfully seeded and updated #{User.count} users from users.json!"
else
  puts "users.json file not found in db/ directory!"
end