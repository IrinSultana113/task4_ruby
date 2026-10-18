class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :full_name
      t.string :email
      t.string :job_position
      t.datetime :last_seen
      t.string :status
      t.string :password_digest

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end