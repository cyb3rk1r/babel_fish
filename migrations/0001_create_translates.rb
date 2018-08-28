Sequel.migration do
  up do
    create_table(:translates) do
      primary_key :id
      String :in, null: false
      String :out, null: false
      String :out_lang, null: false
      Fixnum :chat_id, null: false
    end
  end
  down do
    drop_table(:translates)
  end
end