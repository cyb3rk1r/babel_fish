module SkyengTranslator
  SEARCH = 'https://dictionary.skyeng.ru/api/public/v1/words/search'.freeze
  MEANINGS = 'https://dictionary.skyeng.ru/api/public/v1/meanings'.freeze
  def self.translate(message)
     Oj.load(RestClient.get(SEARCH, params: {_format: 'json', search: message}).body)
  end

  def self.meanings(meaning_ids)
    Oj.load(RestClient.get(MEANINGS, params: { _format: 'json', ids: meaning_ids }).body)
  end
end
