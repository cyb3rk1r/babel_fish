Sequel.migration do
  up do
    create_table(:reminder_meanings) do
      primary_key :id
      Fixnum :chat_id, null: false
      String :meaning_ids, null: false
      Boolean :active, default: true, null: :false
    end
  end
  down do
    drop_table(:translates)
  end
end