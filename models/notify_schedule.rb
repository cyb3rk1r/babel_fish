class NotifySchedule < Sequel::Model(BABEL_FISH_DB[:notify_schedule])
  plugin :validation_helpers
  def validate
    super
    validates_unique([:notify_at, :chat_id])
  end

  def self.markup(chat_id)
    hours = 7.upto(22).to_a.map {|m| format('%02d', m)}
    minutes = 0.step(50,20).to_a.map {|m| format('%02d', m)}
    schedule_scheme = hours.map {|h| minutes.map {|m| h + '-' + m} }.flatten.map do |notify_at|
      NotifySchedule.find_or_create(chat_id: chat_id, notify_at: notify_at)
    end

    kb = schedule_scheme.map do |notify|
      text = format('%{state}%{time}', { time: notify[:notify_at],
                                         state: (notify[:enabled] ? '✅' : '❌' )})
      Telegram::Bot::Types::InlineKeyboardButton.new(text: text,
                                                     callback_data: ('notify_at:%{dt}' % {dt: notify[:notify_at]}),)
    end.each_slice(6).to_a + [
        [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Выключить все',
                                                       callback_data: 'disable_all_notifications'),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Включить все',
                                                       callback_data: 'enable_all_notifications')]
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
end