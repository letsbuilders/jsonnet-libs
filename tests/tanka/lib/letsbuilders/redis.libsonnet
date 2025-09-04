local redis = import 'redis/redis.libsonnet';

{
  _config:: {
    affinity+: {
      nodeAffinity+: {
        requiredDuringSchedulingIgnoredDuringExecution+: {
          nodeSelectorTerms+: [
            {
              matchExpressions: [
                {
                  key: 'test',
                  operator: 'In',
                  values: ['test'],
                },
              ],
            },
          ],
        },
      },
    },
    tolerations: [
      {
        key: 'test',
        value: 'true',
        effect: 'NoSchedule',
      },
    ],
    auth: {
      password: 'password',
    },
  },
  redis: redis.redis($._config),
}
