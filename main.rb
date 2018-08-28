require 'telegram/bot'
require 'easy_translate'
require 'semantic_logger'
require 'pg'
require 'sequel'
require './translate'

SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)
logger = SemanticLogger['BabelFish']

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
google_api_token = ENV.fetch('GOOGLE_API_TOKEN', nil)
database_url = ENV.fetch('DATABASE_URL', nil)

config = {
    telegram_token: telegram_token,
    google_api_token: google_api_token,
    database_url: database_url
}

config.each do |config_key, config_value|
  if config_value.nil?
    message = 'config_key %{config_key} is not set'
    raise message % { config_key: config_key }
  end
end

BABEL_FISH_DB = Sequel.connect(database_url)
EasyTranslate.api_key = google_api_token
Telegram::Bot::Client.run(telegram_token) do |bot|
  bot.listen do |message|
    next unless message.text
    if message.text.length > 300
      bot.api.send_message(chat_id: message.chat.id, text: "limit: 300 letters")
      next
    end

    logger.info(payload: { message_text: message.text,
                           chat_id: message.chat.id })

    begin
      case message.text
      when '/start'
        bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
      when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
      when '/words'
        rel = BABEL_FISH_DB[:translates].where(chat_id: message.chat.id).order(:in)
        words = rel.all.inject('') do |vocabulary, translate|
          vocabulary << '%{from} - %{to}' % { from: translate[:in], to: translate[:out] }
          vocabulary << "\n"
        end
        puts words
        bot.api.send_message(chat_id: message.chat.id, text: words)
      else
        translate_params = Translator.translate(message)
        BABEL_FISH_DB[:translates].insert(translate_params.merge(chat_id: message.chat.id))
        bot.api.send_message(chat_id: message.chat.id, text: translate_params[:out])
      end
    rescue => e
      puts "#{e.inspect}"
      bot.api.send_message(chat_id: message.chat.id, text: 'error')
    end
  end
end
