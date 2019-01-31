require 'bundler'
Bundler.require

require 'telegram/bot'

# require './google_translator.rb'
require './skyeng_translator.rb'
require './bin/sequel'
require './models/notify_schedule'
require './models/reminder_meaning'

SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)
logger = SemanticLogger['BabelFish']

Timezone::Lookup.config(:geonames) do |c|
  c.username = 'okoburi'
end

telegram_token = ENV.fetch('TELEGRAM_TOKEN', nil)
Telegram::Bot::Client.run(telegram_token) do |bot|
  bot.listen do |message|
    begin
      case message
      when Telegram::Bot::Types::CallbackQuery
        callback_query = message.data.split(':')
        case callback_query[0]

        when 'disable_all_notifications'
          message_with_kb_id = message.message.message_id
          chat_id = message.from.id
          NotifySchedule.where(chat_id: chat_id).update(enabled: false)
          markup = NotifySchedule.markup(message.from.id)
          bot.api.edit_message_text(chat_id: message.from.id,
                                    text: 'Расписание напоминаний',
                                    reply_markup: markup,
                                    message_id: message_with_kb_id)
        when 'enable_all_notifications'
          message_with_kb_id = message.message.message_id
          chat_id = message.from.id
          NotifySchedule.where(chat_id: chat_id).update(enabled: true)
          markup = NotifySchedule.markup(message.from.id)
          bot.api.edit_message_text(chat_id: message.from.id,
                                    text: 'Расписание напоминаний',
                                    reply_markup: markup,
                                    message_id: message_with_kb_id)
        when 'notify_at'
          message_with_kb_id = message.message.message_id
          notify_at_params = { notify_at: callback_query[1],
                               chat_id: message.from.id }
          logger.info( payload: notify_at_params.to_s )
          notify = NotifySchedule.find_or_create(notify_at_params)
          notify[:enabled] = !notify[:enabled]
          notify.save
          template_name = 'templates/notify_at_%{state}.liquid' % { state: notify[:enabled] ? 'enabled' : 'disabled' }
          notify_at_text = Tilt.new(template_name).render(time: callback_query[1])
          markup = NotifySchedule.markup(message.from.id)
          bot.api.edit_message_text(chat_id: message.from.id,
                                    text: notify_at_text,
                                    reply_markup: markup,
                                    message_id: message_with_kb_id)
          bot.api.send_message(chat_id: message.from.id, text: notify_at_text)
        when 'remembrancer'
          case callback_query[1]
          when 'stop_remind'
            chat_id = message.from.id
            meaning_ids = callback_query[2]
            ReminderMeaning.where(chat_id: chat_id, active: true, meaning_ids: meaning_ids).delete
            bot.api.send_message(chat_id: chat_id, text: 'Я перестану напоминать это слово')
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
          meaning_sound = 'https:' + meanings_result[0]['soundUrl']
          meanings = Tilt.new('templates/meanings.liquid').render(word: meaning_text,
                                                                  sound: meaning_sound,
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
        when '/schedule'
          notification_schedule_text = Tilt.new('templates/notification_schedule.liquid').render
          markup = NotifySchedule.markup(message.from.id)
          bot.api.send_message(chat_id: message.chat.id,
                               reply_markup: markup,
                               text: notification_schedule_text)
        when '/start'
          notification_schedule_text = Tilt.new('templates/notification_schedule.liquid').render
          markup = NotifySchedule.markup(message.from.id)
          start_response = bot.api.send_message(chat_id: message.chat.id,
                                                reply_markup: markup,
                                                text: notification_schedule_text)
          logger.info(payload: start_response)
        when '/stop'
          bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
        else
          if message.text.length > 300
            bot.api.send_message(chat_id: message.chat.id, text: "limit: 300 letters")
            next
          end
          next if message.text[0] == '/'
          logger.info(payload: { message_text: message.text,
                                 chat_id: message.chat.id })
          skyeng_word_search_result = SkyengTranslator.word_search(message.text)
          kb = skyeng_word_search_result.map do |search_result|
            button_title = format('%{in} %{out}', in: search_result['text'],
                                  out: search_result['meanings'][0]['translation']['text'])
            meaning_ids = search_result['meanings'].map {|m| m['id']}.join(',')
            callback_data = format('meanings:%{meaning_ids}', meaning_ids: meaning_ids)
            Telegram::Bot::Types::InlineKeyboardButton.new(text: button_title,
                                                           callback_data: callback_data)
          end.each_slice(4).to_a
          markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
          bot.api.send_message(chat_id: message.chat.id, text: 'did you mean?', reply_markup: markup)
        end
      end
    rescue => e
      puts "#{e.inspect}"
      bot.api.send_message(chat_id: message.from.id, text: 'error')
      next
      # raise e
    end
  end
end
