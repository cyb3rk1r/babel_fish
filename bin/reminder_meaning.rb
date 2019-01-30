require 'bundler'
Bundler.require
require 'telegram/bot'
require './skyeng_translator'

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
database_url = ENV.fetch('DATABASE_URL', 'postgres://user:password@localhost:5432/babel_fish')
BABEL_FISH_DB = Sequel.connect(database_url)

uniq_chats = BABEL_FISH_DB[:reminder_meanings].where(active: true).all.map {|chat| chat[:chat_id]}.uniq
uniq_chats.each do |chat_id|
  reminder_meaning_queue = BABEL_FISH_DB[:reminder_meanings].where(chat_id: chat_id, active: true).order(:id)
  reminder_meaning = reminder_meaning_queue.first
  meaning_ids = reminder_meaning[:meaning_ids]
  meanings_result = SkyengTranslator.meanings(meaning_ids)
  meaning_text = meanings_result[0]['text']
  meaning_transcription = meanings_result[0]['transcription']
  meaning_translations = meanings_result.map {|meaning| meaning['translation']['text']}.join(', ')

  meaning_image_exist = meanings_result[0]['images'].any?
  meanings = Tilt.new('templates/meanings.liquid').render(word: meaning_text,
                                                          transcription: meaning_transcription,
                                                          translations: meaning_translations)
  kb = %w(stop).map do |command|
    Telegram::Bot::Types::InlineKeyboardButton.new(text: command,
                                                   callback_data: 'remembrancer:' + command  + ':' + meaning_ids)
  end
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [kb])
  reminder_params = meaning_image_exist ? {
      chat_id: chat_id,
      photo: 'https:' + meanings_result[0]['images'][0]['url'],
      caption: meanings, parse_mode: 'markdown',
      reply_markup: markup
  } : {
      chat_id: chat_id,
      text: meanings,
      parse_mode: 'markdown',
      reply_markup: markup
  }


  Telegram::Bot::Client.run(telegram_token) do |bot|
    if meaning_image_exist
      bot.api.send_photo(reminder_params)#, reply_markup: markup)
    else
      bot.api.send_message(reminder_params)
    end
  end
  id = reminder_meaning.delete(:id)
  BABEL_FISH_DB[:reminder_meanings].where(chat_id: chat_id, active: true, id: id).delete
  BABEL_FISH_DB[:reminder_meanings].insert(reminder_meaning)
end
