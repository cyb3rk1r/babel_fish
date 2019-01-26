module SkyengTranslator
  SEARCH = 'https://dictionary.skyeng.ru/api/public/v1/words/search'.freeze
  def self.translate(message)
    words = message.split(' ')
    words.each do |word|
      # curl '
      # https://dictionary.skyeng.ru/api/public/v1/words/search?_format=json&search=empower'
      # -H 'Accept: application/json'
      # -H 'Accept-Language: ru-RU,ru;q=0.8,en-US;q=0.5,en;q=0.3'
      # --compressed
      # -H 'Referer: https://dictionary.skyeng.ru/doc/api/external'
      # -H 'Content-type: application/json'
      # -H 'DNT: 1'
      # -H 'Connection: keep-alive'
      # -H '
      #
      resp = RestClient.get(SEARCH, params: {_format: 'json', search: word} )
      resp_body = resp.body
      meanings = JSON.parse(resp_body)
    end
  end
end
