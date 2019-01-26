require 'sidekiq'
require 'tilt'
require 'liquid'
require 'telegram/bot'
require 'byebug'
require './skyeng_translator'
require 'oj'
require 'rest-client'

class Remembrancer
  include Sidekiq::Worker

  def perform(*args)
  chat_id = args[0]['chat_id']
  meaning_id = args[0]['meaning_id']
  meanings = SkyengTranslator.meanings(meaning_id)
  telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
  message_text = Tilt.new('templates/word_meaning.liquid').render(text: meanings[0]['text'], entity: meanings[0])
  Telegram::Bot::Client.run(telegram_token) do |bot|
    bot.api.send_message(chat_id: chat_id, text: message_text, parse_mode: 'html')
  end
  end
end