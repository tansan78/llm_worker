import os
import redis

redis_host = os.environ.get("REDISHOST", "localhost")
redis_port = int(os.environ.get("REDISPORT", 6379))
redis_client = redis.StrictRedis(host=redis_host, port=redis_port)


def get_redis_client():
    return redis_client