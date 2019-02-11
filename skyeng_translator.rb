module SkyengTranslator
  IMAGE_QUALITY = 50
  WORD_SEARCH_URL = 'https://dictionary.skyeng.ru/api/public/v1/words/search'.freeze
  MEANINGS_URL = 'https://dictionary.skyeng.ru/api/public/v1/meanings'.freeze
  def self.translation(word)
    Oj.load(RestClient.get(WORD_SEARCH_URL, params: {search: word, _format: 'json'}))
  end
  def self.meanings(ids)
    Oj.load(RestClient.get(MEANINGS_URL, params: {ids: ids, quality: IMAGE_QUALITY}))
  end
end