require 'telegram/bot'
require 'easy_translate'

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
google_api_token = ENV.fetch( 'GOOGLE_API_TOKEN', nil)

Telegram::Bot::Client.run(telegram_token) do |bot|
  bot.listen do |message|
    next unless message.text
    if message.text.length > 300
      bot.api.send_message(chat_id: message.chat.id, text: "limit: 300 letters")
      next
    end

    begin
      case message.text
      when '/start'
        bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
      when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
      else
        translate =  EasyTranslate.translate(message.text, :to => :ru, :key => google_api_token)
        bot.api.send_message(chat_id: message.chat.id, text: translate)
      end
    rescue => e
      puts "#{e.inspect}"
      bot.api.send_message(chat_id: message.chat.id, text: 'error')
    end
  end
end
