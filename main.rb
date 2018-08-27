require 'telegram/bot'
require 'easy_translate'
require 'semantic_logger'

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
google_api_token = ENV.fetch( 'GOOGLE_API_TOKEN', nil)
EasyTranslate.api_key = google_api_token
SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)

logger = SemanticLogger['BabelFish']

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
        # create vocabulary for that chat
        bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
      when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
      else
        cyrillic_letters = message.text.match(/\p{Cyrillic}/)
        language = cyrillic_letters ? :en : :ru
        translate =  EasyTranslate.translate(message.text, :to => language)
        bot.api.send_message(chat_id: message.chat.id, text: translate)
      end
    rescue => e
      puts "#{e.inspect}"
      bot.api.send_message(chat_id: message.chat.id, text: 'error')
    end
  end
end
