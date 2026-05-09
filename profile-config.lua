urban_density_path = os.getenv('URBAN_DENSITY_PATH')

local redis = require('redis')
redis_conn = assert(redis.connect(os.getenv('REDIS_HOST', 'localhost'), os.getenv('REDIS_PORT', 6379)))
