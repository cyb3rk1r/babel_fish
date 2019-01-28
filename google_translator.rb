module GoogleTranslator
  def self.translate(message)
    cyrillic_letters = message.text.match(/\p{Cyrillic}/)
    out_lang = cyrillic_letters ? :en : :ru
    EasyTranslate.translate(message.text, to: out_lang)
  end
end
