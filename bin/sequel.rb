require 'sequel'
require 'que'

database_url = ENV.fetch('DATABASE_URL', nil)
Sequel.extension :core_extensions
Sequel.extension :pg_json_ops
BABEL_FISH_DB =  Sequel.connect(database_url)
BABEL_FISH_DB.extension :pg_array, :pg_json
Que.connection = BABEL_FISH_DB

SemanticLogger.default_level = :trace
SemanticLogger.add_appender(io: $stdout, formatter: :color)
logger = SemanticLogger['BabelFish']

Que.logger = logger
