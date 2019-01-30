require 'bundler'
Bundler.require

require 'telegram/bot'

# require './google_translator.rb'
require './skyeng_translator.rb'

SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)
logger = SemanticLogger['BabelFish']

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
database_url = ENV.fetch('DATABASE_URL', nil)
# google_api_token = ENV.fetch('GOOGLE_API_TOKEN', nil)

BABEL_FISH_DB = Sequel.connect(database_url)
# EasyTranslate.api_key = google_api_token
Telegram::Bot::Client.run(telegram_token) do |bot|
  bot.listen do |message|

    begin
      case message
      when Telegram::Bot::Types::CallbackQuery
        callback_query = message.data.split(':')
        case callback_query[0]
        when 'remembrancer'
          case callback_query[1]
          when 'reminder_meaning'
            reminder_meaning_params = { chat_id: message.from.id,
                                        meaning_ids: callback_query[2],
                                        active: true }
            BABEL_FISH_DB[:reminder_meanings].insert(reminder_meaning_params)
            bot.api.send_message(chat_id: message.from.id, text: 'Remembrancer on his watch')
          when 'stop'
            BABEL_FISH_DB[:reminder_meanings].where(chat_id: message.from.id,
                                                    meaning_ids: callback_query[1]).update(active: false)
            bot.api.send_message(chat_id: message.from.id, text: 'Reminder has been disabled')
          when 'send_to_skyeng'
            bot.api.send_message(chat_id: message.from.id, text: 'To be implemented..')
          end
        when 'meanings'
          meaning_ids = callback_query[1]
          meanings_result = SkyengTranslator.meanings(meaning_ids)
          meaning_text = meanings_result[0]['text']
          meaning_transcription = meanings_result[0]['transcription']
          meaning_photo = 'https:' + meanings_result[0]['images'][0]['url']
          meaning_translations = meanings_result.map {|meaning| meaning['translation']['text']}.join(', ')
          meanings = Tilt.new('templates/meanings.liquid').render(word: meaning_text,
                                                                  transcription: meaning_transcription,
                                                                  translations: meaning_translations)
          kb = %w(reminder_meaning sync).map do |command|
            Telegram::Bot::Types::InlineKeyboardButton.new(text: command,
                                                           callback_data: 'remembrancer:' + command  + ':' + callback_query[1])
          end
          markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [kb])
          bot.api.send_photo(chat_id: message.from.id,
                             photo: meaning_photo,
                             caption: meanings, parse_mode: 'markdown',
                             reply_markup: markup)#, reply_markup: markup)
        end
      when Telegram::Bot::Types::Message
        next unless message.text
        case message.text
        when '/start'
          bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
        when '/stop'
          bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
        else
          if message.text.length > 300
            bot.api.send_message(chat_id: message.chat.id, text: "limit: 300 letters")
            next
          end
          logger.info(payload: { message_text: message.text,
                                 chat_id: message.chat.id })
          # translate_params = GoogleTranslator.translate(message)
          skyeng_word_search_result = SkyengTranslator.word_search(message.text)
          # template = Tilt.new('templates/entity_card.liquid').render(args: skyeng_word_search_result)
          kb = skyeng_word_search_result.map do |search_result|
            button_title = format('%{in} %{out}', in: search_result['text'],
                                  out: search_result['meanings'][0]['translation']['text'])
            meaning_ids = search_result['meanings'].map {|m| m['id']}.join(',')
            callback_data = format('meanings:%{meaning_ids}', meaning_ids: meaning_ids)
            Telegram::Bot::Types::InlineKeyboardButton.new(text: button_title,
                                                           callback_data: callback_data)
          end.each_slice(4).to_a
          # kb = [
          #     (text: 'Touch me', callback_data: 'touch'),
          # ]
          markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
          bot.api.send_message(chat_id: message.chat.id, text: 'did you mean?', reply_markup: markup)
        end
      end
    rescue => e
      puts "#{e.inspect}"
      bot.api.send_message(chat_id: message.from.id, text: 'error')
    end
  end
end
