require 'bundler'
Bundler.require
require './bin/sequel'
require './models/notify_schedule'
require './models/reminder_meaning'
require 'sidekiq'
require 'telegram/bot'
require './skyeng_translator'

rediscloud_url = ENV.fetch('REDISCLOUD_URL', nil)
Sidekiq.configure_client do |config|
  defaults = { db: 1 }
  config.redis = rediscloud_url ? { url: rediscloud_url } : defaults
end

Sidekiq.configure_server do |config|
  defaults = { db: 1 }
  config.redis = rediscloud_url ? { url: rediscloud_url } : defaults
end

class Worker
  include Sidekiq::Worker
  def perform(chat_id)
    telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
    Telegram::Bot::Client.run(telegram_token) do |bot|

      reminder = ReminderMeaning.where(chat_id: chat_id, active: true).order(:id).first

      meaning_ids = reminder.meaning_ids
      meanings_result = SkyengTranslator.meanings(meaning_ids)
      meaning_text = meanings_result[0]['text']
      meaning_transcription = meanings_result[0]['transcription']
      meaning_photo = 'https:' + meanings_result[0]['images'][0]['url']
      meaning_translations = meanings_result.map {|meaning| meaning['translation']['text']}.join(', ')
      meanings = Tilt.new('templates/meanings.liquid').render(word: meaning_text,
                                                              transcription: meaning_transcription,
                                                              translations: meaning_translations)
      kb = %w(stop_remind).map do |command|
        Telegram::Bot::Types::InlineKeyboardButton.new(text: command,
                                                       callback_data: 'remembrancer:' + command  + ':' + meaning_ids)
      end
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [kb])

      bot.api.send_photo(chat_id: chat_id,
                         photo: meaning_photo,
                         caption: meanings, parse_mode: 'markdown',
                         reply_markup: markup)
      reminder_meaning_queued = ReminderMeaning.new(chat_id: chat_id,
                                                    active: true,
                                                    meaning_ids: reminder.meaning_ids)
      reminder.delete
      reminder_meaning_queued.save
    end
  end
end




