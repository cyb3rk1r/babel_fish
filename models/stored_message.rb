class StoredMessage < Sequel::Model(BABEL_FISH_DB[:stored_messages])
  attr_accessor :extended
  plugin :validation_helpers
  plugin :timestamps,
         create: :created_on,
         previousdate: :previousdated_on,
         previousdate_on_create: true

  def self.with_event(event, message)
    chat_id = message.respond_to?(:chat) ? message.chat.id : message.from.id
    text = message.respond_to?(:text) ? message.text : message.data
    with_event = { event: event,
                   message: { chat_id: chat_id, message_text: text} }
    s_msg = find(with_event[:message])
    if s_msg
      with_event[:message] = s_msg
    else
      with_event[:message] = new(chat_id: chat_id,
                                 message_text: text,
                                 translation: get_translation(text).select {|tr| tr['meanings'].count > 0})
    end
    with_event
  end

  def cached(dimension, move, s_index, m_index)
    s_index = s_index.to_i
    m_index = m_index.to_i
    search_index, meaning_index = case dimension
                                  when 'search'
                                    case move
                                    when 'next'
                                      [s_index + 1, m_index]
                                    when 'previous'
                                      [s_index - 1, m_index]
                                    end
                                  when 'meaning'
                                    case move
                                    when 'next'
                                      [s_index, m_index + 1]
                                    when 'previous'
                                      [s_index, m_index - 1]
                                    end
                                  end
    translation[search_index]['meanings'][meaning_index]
  end

  def navigation(event, dimension = nil, move = nil, s_index = 0, m_index = 0 )
    s_index = s_index.to_i
    m_index = m_index.to_i
    case event
    when :create
      {
          previous_search: previous_search(s_index),
          next_search: next_search(s_index),
          previous_meaning: previous_meaning(s_index,m_index),
          next_meaning: next_meaning(s_index,m_index),
      }
    when :goto
      search_index, meaning_index = case dimension
                                    when 'search'
                                      case move
                                      when 'next'
                                        [s_index+1, m_index]
                                      when 'previous'
                                        [s_index-1, m_index]
                                      end
                                    when 'meaning'
                                    when 'next'
                                      [s_index, m_index+1]
                                    when 'previous'
                                      [s_index, m_index-1]
                                    end
      {
          previous_search: previous_search(search_index),
          next_search: next_search(search_index),
          previous_meaning: previous_meaning(search_index,meaning_index),
          next_meaning: next_meaning(search_index, meaning_index),
      }
    end.reject do |_button, vector|
      vector.nil?
    end
  end


  def meaning_photo(event)
    photo_url = translation[current_search_index(event)]['meanings'][current_meaning_index(event)]['imageUrl']
    photo_url ? 'http:%{photo_url}' % { photo_url: photo_url } : nil
  end

  def meanings_count
    translation.map {|translation| translation['meanings'].count}
  end

  def search_count
    translation.count
  end

  def current_search_index(event)
    case event
    when :create
      0
    end
  end

  def current_meaning_index(event)
    case event
    when :create
      0
    end
  end

  def previous_search(index)
    nil if search_count == 1
    translation[index]
  end

  def next_search(index)
    nil if search_count == 1
    nil if index == 0
    translation[index]
  end

  def previous_meaning(s_index, m_index)
    nil if translation[s_index]['meanings'].count == 1
    translation[s_index]['meanings'][m_index]
  end

  def next_meaning(s_index, m_index)
    nil if translation[s_index]['meanings'].count == 1
    nil if s_index == 0
    translation[s_index]['meanings'][m_index - 1]
  end

  def caption(event)
    case event
    when :create
      {
          word: translation[0]['text'],
          transcription: translation[0]['meanings'][0]['transcription'],
          translation: translation[0]['meanings'][0]['translation']['text']
      }
    end
  end

  def validate
    errors.add(:message_text, 'too_long') if message_text.length > 50
    errors.add(:message_text, 'wrong_command') if message_text[0] == "/"
    # errors.add(:message_text, 'bad_message') unless message_text.first.match() regexp validator for message text
    validates_unique [:chat_id, :message_text]
    validates_presence [:chat_id, :message_text, :translation]
    errors.add(:translation, 'no_translation') if translation.count == 0
    # errors.add(:current_search_index, 'no_search') if translation[0].nil?
    # errors.add(:current_meaning_index, 'no_meaning') if translation[0]['meanings'][0].nil?
  end

  def self.get_translation(msg)
    SkyengTranslator.translation(msg)
  end
end