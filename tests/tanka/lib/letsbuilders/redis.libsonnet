local redis = import 'redis/redis.libsonnet';

{
  _config:: {
    auth: {
      password: 'password',
    }
  },
  redis: redis.redis($._config)
}