class MeaningEntity < Grape::Entity
  BUTTONS_EMOJI = { previous_search: '🔺️',
                    previous_meaning: '◀️',
                    next_search: '🔻',
                    next_meaning: '▶️',
                    listen: '📢',
                    rmrmbr: '️💔',
                    remember: '❤️' }

  expose :s_index
  expose :m_index
  expose :caption
  expose :meaning_photo
  expose :markup
  expose :audio
  private

  def meaning
    object.translation[s_index]['meanings'][m_index]
  end

  def meaning_photo
    return nil if meaning.nil?
    meaning['imageUrl'] ? format('https:%{urlpart}', urlpart: meaning['imageUrl']) : nil
  end

  def audio
    return nil if meaning.nil?
    meaning['soundUrl'] ? format('https:%{urlpart}', urlpart: meaning['soundUrl']) : nil
  end

  def markup
    search_controls = [previous_search, next_search].compact
    meaning_controls = [previous_meaning, next_meaning].compact
    controls = [listen, remembrancer].compact
    keyboard = [search_controls,meaning_controls, controls].map do |button_group|
      button_group.map do |button|
        Telegram::Bot::Types::InlineKeyboardButton.new(text: button[:text],
                                                       callback_data: button[:callback_data])
      end
    end
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
  end

  def listen
    txt = I18n.t('listen_text') % { word: object.translation[s_index]['text'] }
    {
        text: BUTTONS_EMOJI[:listen] + txt,
        callback_data: format('listen:%{object_id}:%{s_index}:%{m_index}',
                              object_id: object.id,
                              s_index: s_index,
                              m_index: m_index)
    }
  end

  def remembrancer
    if options[:rmrmbr]
      txt = I18n.t('rm_remember_text') % { word: object.translation[s_index]['text'] }
      {
          text: BUTTONS_EMOJI[:rmrmbr] + txt,
          callback_data: format('rmrmbr:%{object_id}:%{s_index}:%{m_index}',
                                object_id: object.id,
                                s_index: s_index,
                                m_index: m_index)
      } else
          txt = I18n.t('remember_text') % { word: object.translation[s_index]['text'] }
          {
              text: BUTTONS_EMOJI[:remember] + txt,
              callback_data: format('rmbr:%{object_id}:%{s_index}:%{m_index}',
                                    object_id: object.id,
                                    s_index: s_index,
                                    m_index: m_index)
          }
    end
  end

  def stop_remind
    {
        text: BUTTONS_EMOJI[:stop_remind],
        callback_data: format('rmbr:%{object_id}:%{s_index}:%{m_index}',
                              object_id: object.id,
                              s_index: s_index,
                              m_index: m_index)
    }
  end

  def search_count
    object.translation.count
  end

  def previous_search
    return nil if search_count == 1
    return nil if object.translation[s_index - 1].nil?
    return nil if s_index == 0
    txt = object.translation[s_index-1]['text']
    {
        text: BUTTONS_EMOJI[:previous_search] + txt,
        callback_data: format('previous_search:%{object_id}:%{s_index}:%{m_index}',
                              object_id: object.id,
                              s_index: s_index,
                              m_index: m_index)
    }
  end

  def previous_meaning
    return nil if object.translation[s_index]['meanings'].count == 1
    return nil if object.translation[s_index]['meanings'][m_index - 1].nil?
    return nil if m_index == 0
    txt = object.translation[s_index]['meanings'][m_index-1]['translation']['text']
    {
        text: BUTTONS_EMOJI[:previous_meaning] + txt,
        callback_data: format('previous_meaning:%{object_id}:%{s_index}:%{m_index}',
                              object_id: object.id,
                              s_index: s_index,
                              m_index: m_index)
    }
  end

  def next_search
    return nil if search_count == 1
    return nil if object.translation[s_index + 1].nil?
    txt = object.translation[s_index+1]['text']
    {
        text: BUTTONS_EMOJI[:next_search] + txt,
        callback_data: format('next_search:%{object_id}:%{s_index}:%{m_index}',
                              object_id: object.id,
                              s_index: s_index,
                              m_index: m_index)
    }
  end

  def next_meaning
    return nil if object.translation[s_index]['meanings'].count == 1
    return nil if object.translation[s_index]['meanings'][m_index + 1].nil?
    txt = object.translation[s_index]['meanings'][m_index+1]['translation']['text']
    {
        text: BUTTONS_EMOJI[:next_meaning] + txt,
        callback_data: format('next_meaning:%{object_id}:%{s_index}:%{m_index}',
                              object_id: object.id,
                              s_index: s_index,
                              m_index: m_index)
    }
  end

  def caption
    return nil if meaning.nil?
    params = {
        word: object.translation[s_index]['text'],
        transcription: object.translation[s_index]['meanings'][m_index]['transcription'],
        translation: object.translation[s_index]['meanings'][m_index]['translation']['text']
    }
    Tilt.new('views/caption.liquid').render(params)
  end

  def s_index
    current_s_index = options[:s_index].to_i
    current_s_index = options['next_search'] ? current_s_index + 1 : current_s_index
    options['previous_search'] ? current_s_index - 1 : current_s_index
  end

  def m_index
    current_m_index = options[:m_index].to_i
    current_m_index = options['next_meaning'] ? current_m_index + 1 : current_m_index
    current_m_index = options['previous_meaning'] ? current_m_index - 1 : current_m_index
    current_m_index = options['next_search'] ? 0 : current_m_index
    options['previous_search'] ? 0 : current_m_index
  end
end