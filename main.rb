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
        chat_id = message.from.id
        callback_query = message.data.split(':')
        move, id, s_index, m_index = callback_query
        case move
        when 'rmbr'
          ForgettingCurve.schedule(Time.now).each do |run_at|
            # ForgettingCurve.enqueue(chat_id: chat_id.to_s,
            #                         id: id.to_s,
            #                         s_index: s_index.to_s,
            #                         m_index: m_index.to_s, run_at: run_at)
            ForgettingCurve.enqueue(chat_id.to_s, id.to_s, s_index.to_s, m_index.to_s, run_at: run_at)
          end
          rmrmbr = true
        when 'rmrmbr'
          [:chat_id, :id, :s_index, :m_index]
          options = [chat_id, id, s_index, m_index].map(&:to_s)
          args = Sequel.pg_jsonb_op(:args)
          BABEL_FISH_DB[:que_jobs].where(args.get_text(0) => options[0],
                                         args.get_text(1) => options[1],
                                         args.get_text(2) => options[2],
                                         args.get_text(3) => options[3]).delete
          rmrmbr = false
        end
        presented = MeaningEntity.represent(StoredMessage.find(id: id), { move => true,
                                                                          rmrmbr: rmrmbr,
                                                                          s_index: s_index,
                                                                          m_index: m_index}).as_json
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
      when Telegram::Bot::Types::Message
        next unless message.text
        case message.text
        when '/start'
          greeting = Tilt.new('views/greeting.liquid').render
          bot.api.send_message(chat_id: message.chat.id, text: greeting, parse_mode: 'markdown' )
        when '/stop'
          BABEL_FISH_DB[:que_jobs].where(args.get_text(0) => message.chat.id.to_s).delete
          bye = Tilt.new('views/bye.liquid').render
          bot.api.send_message(chat_id: message.chat.id, text: bye)
        else
          stored_message = StoredMessage.with_event(:create, message)
          if stored_message[:message].valid?
            stored_message[:message].save
            presented = MeaningEntity.represent(stored_message[:message]).as_json
            if presented[:meaning_photo]
              bot.api.send_photo(chat_id: message.from.id,
                                 photo: presented[:meaning_photo],#stored_message[:message].meaning_photo(stored_message[:event]),
                                 caption: presented[:caption],
                                 parse_mode: 'markdown',
                                 reply_markup: presented[:markup])
            end
          else
            # errors = message.errors.map do |klass, ers|
            #   ers.map do |errcode|
            #     i18n_key = 'errors.%{klass}.%{errcode}' % { klass: klass, errcode: errcode }
            #     I18n.t(i18n_key)
            #   end
            # end
            # errors_text = Tilt.new('views/errors.liquid').render(errors: errors)
            # bot.api.send_message(chat_id: message.chat.id, text: errors_text)
            next
          end
        end
      end
    rescue => e
      logger.error(e)
      bot.api.send_message(chat_id: message.from.id, text: 'error')
      next
      # raise e
    end
  end
end
