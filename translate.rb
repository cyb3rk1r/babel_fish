module Translator
  def self.translate(message)
    cyrillic_letters = message.text.match(/\p{Cyrillic}/)
    out_lang = cyrillic_letters ? :en : :ru
    translate = EasyTranslate.translate(message.text, to: out_lang)
    { in: message.text, out: translate, out_lang: out_lang.to_s }
  end
end
