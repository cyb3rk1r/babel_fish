require 'bundler'
Bundler.require

require 'telegram/bot'
require './bin/sequel'
require 'grape-entity'
require 'active_support/core_ext/numeric/time.rb'

require './models/stored_message'
require './models/forgetting_curve'
require './entities/meaning_entity'

require './skyeng_translator.rb'
require './locales/locale.rb'


class ForgettingCurve < Que::Job

  def self.schedule(dt)
    [
        dt + 5.seconds,
        dt + 25.seconds,
        dt + 2.minutes,
        dt + 10.minutes,
        dt + 1.hour,
        dt + 5.hour,
        dt + 1.day,
        dt + 3.day,
        dt + 5.day,
        dt + 7.day,
        dt + 14.day,
        dt + 25.day,
        dt + 8.week,
        dt + 16.week
    ]
  end

  def run(chat_id, id, s_index, m_index)
    stored_message_id = id
    search_index = s_index
    meaning_index = m_index
    telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
    Telegram::Bot::Client.run(telegram_token) do |bot|
      stored = StoredMessage.find(id: stored_message_id)
      presented = MeaningEntity.represent(stored, rmrmbr: true, s_index: search_index, m_index: meaning_index).as_json
      if presented[:meaning_photo]
        bot.api.send_photo(chat_id: chat_id,
                           photo: presented[:meaning_photo],
                           caption: presented[:caption],
                           parse_mode: 'markdown',
                           reply_markup: presented[:markup])
      else
        bot.api.send_message(chat_id: message.from.id,
                             text: presented[:caption],
                             parse_mode: 'markdown',
                             reply_markup: presented[:markup]
        )
      end
    end
  end
end
