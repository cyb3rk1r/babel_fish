class CreateStoredMessages < ActiveRecord::Migration[5.2]
  def change
    create_table :stored_messages do |t|
      t.integer :chat_id, null: false
      t.string :message_text, null: false
      t.column :translation, 'jsonb[]'
      t.timestamp
    end
  end
end
