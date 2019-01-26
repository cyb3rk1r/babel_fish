require 'telegram/bot'
require 'oj'
require 'tilt'
require 'semantic_logger'
require 'rest-client'
require './skyeng_translator'
require 'byebug'
require 'sidekiq'
require 'sidekiq/cron'

SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)
logger = SemanticLogger['BabelFish']

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)

remembrancer_call = proc do |message, entity|
  format('remembrancer:%{chat_id}:%{meaning_id}',
         chat_id: message.from.id,
         meaning_id: entity['meanings'][0]['id'])
end
# remembrancer_text_call = proc do |entity|
#   format('%{text} %{translation}',
#          text: entity['text'],
#          translation: entity['meanings'][0]['translation']['text']
#   )
# end
Telegram::Bot::Client.run(telegram_token) do |bot|
  bot.listen do |message|
    begin
      case message
      when Telegram::Bot::Types::CallbackQuery
        callback_command = message.data.split(':')
        case callback_command[0]
        when 'remembrancer'
          chat_id = callback_command[1]
          meaning_id = callback_command[2]
          remembrancer_job_name = format('remembrancer:%{chat_id}:%{meaning_id}',
                                         chat_id: chat_id,
                                         meaning_id: meaning_id)
          Sidekiq::Cron::Job.create(name: remembrancer_job_name,
                                    cron: '*/10 * * * *',
                                    class: 'Remembrancer',
                                    args: { chat_id: chat_id, meaning_id: meaning_id } ) # execute at every 5 minutes, ex: 12:05, 12:10, 12:15...etc
        when 'more'
          chat_id = callback_command[1]
          meaning_id = callback_command[2]
          meanings = SkyengTranslator.meanings(meaning_id)
          if meanings.any?
            Tilt.new('templates/word_more.liquid').render(text: meanings[0]['text'], entity: meanings[0])
          end
        else
          next
        end
      when Telegram::Bot::Types::InlineQuery
        search_results = SkyengTranslator.translate(message.query)
        results = search_results.each_with_index.map do |search_result, id|
          attrs = {}
          attrs[:id] = id
          attrs[:title] = [search_result['text'], search_result['meanings'][0]['translation']['text']].join(' ')

          message_text = Tilt.new('templates/word_landing.liquid').render(text: search_result['text'],
                                                                          transciption: search_result['meanings'][0]['transcription'],
                                                                          image: ['https:', search_result['meanings'][0]['imageUrl']].join(),
                                                                          translation: search_result['meanings'][0]['translation']['text'])
          attrs['input_message_content'] = Telegram::Bot::Types::InputTextMessageContent.new(message_text: message_text, parse_mode: 'html')
          attrs['reply_markup'] = %w(more repeat forget).map do |command|
            Telegram::Bot::Types::InlineKeyboardButton.new(text: command,
                                                           callback_data: remembrancer_call.call(message, search_result))
          end.each_slice(3).to_a
          attrs[:thumb_url] = 'https:' + search_result['meanings'][0]['previewUrl'] if search_result['meanings'][0]['previewUrl']
          attrs
          # input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(message_text: arr[2])
          # )

          # markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: response_kb)
        end.map! do |params|
          markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: params.delete('reply_markup'))
          params.merge!(reply_markup: markup)
          Telegram::Bot::Types::InlineQueryResultArticle.new(params)
        end

        bot.api.answer_inline_query(inline_query_id: message.id, results: results)
      else
        next unless message.text
        logger.info(payload: 'wat')
        logger.info(payload: message.text)
        # bot.api.send_message(chat_id: message.chat.id, text: message.text)
      # if message.text.length > 300
      #
      #   next
      # end
      # logger.info(payload: { message_text: message.text,
      #                        chat_id: message.chat.id })
      #         # case message.text
      #         # when '/start'
              #   bot.api.send_message(chat_id: message.chat.id, text: "DON'T PANIC")
      #         # when '/stop'
      #         #   bot.api.send_message(chat_id: message.chat.id, text: "42")
      end
    rescue => e
      raise e
      # puts "#{e.inspect}"
      # bot.api.send_message(chat_id: message.chat.id, text: 'error')
    end
  end
end
