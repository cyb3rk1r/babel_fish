require 'telegram/bot'
require 'easy_translate'
require 'semantic_logger'

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
google_api_token = ENV.fetch( 'GOOGLE_API_TOKEN', nil)
EasyTranslate.api_key = google_api_token
SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)

logger = SemanticLogger['BabelFish']

babel_fish_logo = <<EOF
                                                    _
                  __....---------------.       _.-'' |
               ,:'_ \__      '._`-.,--- `.    / _.-' |
     _       ,'',-.`.  |_____   `-:_`-.,- \  / / _.- |
    | `.   ,' : `-' ;_,'---. `--..__`-:._`-`' /,'__. :
    |:  `.' o-'`---'  |    |     .--`---<----<:-..__ /
    |::--._.      __.-'  _ |.--.-'---.   )-,. \\`. .  \\
    |:  ,.  `'`.,'  , , / |:| _|    ,' ,`-/  \ \\ `. :
    |_,'  `-.    _.',' (_ |:| _| _,','`- /    \ \`.  |
             `-.__  [|_| ||:|__,','`--- /      \ \ ` |
                  `-..._______.:..-----' SSt    \_`. |
                                                  `-.|
EOF
logger.info(babel_fish_logo)

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
        translate =  EasyTranslate.translate(message.text, :to => :ru)
        bot.api.send_message(chat_id: message.chat.id, text: translate)
      end
    rescue => e
      puts "#{e.inspect}"
      bot.api.send_message(chat_id: message.chat.id, text: 'error')
    end
  end
end
