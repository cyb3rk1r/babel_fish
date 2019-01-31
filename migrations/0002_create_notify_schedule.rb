Sequel.migration do
  up do
    create_table(:notify_schedule) do
      primary_key :id
      String :notify_at, null: false
      Boolean :enabled, default: false, null: false
      Fixnum :chat_id, null: false
    end
  end
  down do
    drop_table(:notify_schedule)
  end
end