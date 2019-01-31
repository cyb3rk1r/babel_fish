require 'sequel'

database_url = ENV.fetch('DATABASE_URL', nil)
BABEL_FISH_DB = Sequel.connect(database_url)
