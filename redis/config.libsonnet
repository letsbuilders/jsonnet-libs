{
  _config:: {
    local s = self,
    name: 'redis',
    _name:: if s.name != 'redis' then 'redis-%s' % s.name else s.name,
    metrics: {
      image: {
        registry: 'docker.io',
        repository: 'oliver006/redis_exporter',
        tag: 'v1.76.0',
      },
    },
    podAnnotations: {
      'prometheus.io/path': '/metrics',
      'prometheus.io/port': '9121',
      'prometheus.io/scrape': 'true',
      'sidecar.istio.io/proxyCPU': '10m',
      'sidecar.istio.io/proxyMemory': '64Mi',
    },
    commonLabels: {
      'app.kubernetes.io/instance': 'redis',
      'app.kubernetes.io/name': s.name,
    },
    image: {
      registry: 'docker.io',
      repository: 'library/redis',
      tag: '6.2.8-bullseye',
    },
    replicas: 1,
    readinessProbe: {
      initialDelaySeconds: 5,
      periodSeconds: 10,
      timeoutSeconds: 5,
      failureThreshold: 6,
      successThreshold: 1,
    },
    livenessProbe: {
      initialDelaySeconds: 30,
      periodSeconds: 10,
      timeoutSeconds: 5,
      failureThreshold: 6,
      successThreshold: 1,
    },
    affinity: {
      nodeAffinity: {
        requiredDuringSchedulingIgnoredDuringExecution: {
          nodeSelectorTerms: [],
          assert std.length(self.nodeSelectorTerms) > 0 : 'nodeSelectorTerms cannot be empty',
        },
      },
    },
    tolerations: [],
    command: [
      '/bin/sh',
      '-c',
      'redis-server --include %(mountPath)s/redis.conf --include %(mountPath)s/master.conf --port ${REDIS_PORT} --requirepass ${REDIS_PASSWORD}' % { mountPath: s.config.mountPath },
    ],
    auth: {
      password: error '_config.auth.password cannot be empty',
    },
    config: {
      mountPath: '/usr/local/etc/redis',
      _redisMaxMem:: (function(x) std.format('%dmb', (std.parseInt(std.substr(x, 0, std.length(x) - 2)) * 0.8 * (if std.endsWith(x, 'Gi') then 1024 else 1))))(s.resources.limits.memory),
      content: {
        'master.conf': |||
          dir /data
          # User-supplied master configuration:
          databases 100
          rename-command FLUSHDB ""
          rename-command FLUSHALL ""
          # End of master configuration
        |||,
        'redis.conf': |||
          # Enable AOF https://redis.io/topics/persistence#append-only-file
          appendonly yes
          # Disable RDB persistence, AOF persistence already enabled.
          save ""
          maxmemory %s
        ||| % s.config._redisMaxMem,
      },
    },

    persistence: {
      enabled: true,
      storageClass: '',
      accessMode: 'ReadWriteOnce',
      size: '8Gi',
      mountPath: '/data',
      annotations: {},
    },
    resources: {
      limits: { memory: '256Mi' },
      requests: {
        cpu: '50m',
        memory: '128Mi',
      },
    },
  },
}
