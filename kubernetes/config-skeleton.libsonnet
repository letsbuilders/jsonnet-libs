{
  _config:: {
    local s = self,

    namespace: error '_config.namespace must be set',
    clusterDomain: error 'clusterDomain has to be set',
    envDomain: '%(namespace)s.%(clusterDomain)s' % { namespace: s.namespace, clusterDomain: s.clusterDomain },

    common: {
      // Shared settings between Deployment, StatefulSet and Job objects
      local common = self,

      name: s.name,

      // Object labels
      labels: {
        'app.kubernetes.io/name': common.name,
        'app.kubernetes.io/instance': '%s-%s' % [common.name, s.namespace],
        'app.kubernetes.io/part-of': 'letsbuild',
      },

      // Object annotations
      annotations: {},

      autoscaling: {
        enabled: false,
        name: common.name,
        annotations: {
          'argocd.argoproj.io/sync-wave': '2',
        },
        scaleTarget: {
          apiVersion: 'apps/v1',
          kind: 'Deployment',
          name: common.name,
        },
        minReplicas: 3,
        maxReplicas: 6,

        metrics: [{
          type: 'Resource',
          resource: {
            name: 'cpu',
            target: {
              type: 'Utilization',
              averageUtilization: 80,
            },
          },
        }],
        behavior: {
          // This matches the default HPA behavior
          // https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#default-behavior
          scaleDown: {
            selectPolicy: 'Min',
            stabilizationWindowSeconds: 300,
            policies: [
              {
                type: 'Percent',
                value: 100,
                periodSeconds: 15,
              },
            ],
          },
          scaleUp: {
            selectPolicy: 'Max',
            stabilizationWindowSeconds: 0,
            policies: [
              {
                type: 'Percent',
                value: 100,
                periodSeconds: 15,
              },
              {
                type: 'Pods',
                value: 4,
                periodSeconds: 15,
              },
            ],
          },
        },
        keda: {
          enabled: false,
          trigerConfigs: [],
          fallback: {
            failureThreshold: 3,
            replicas: common.autoscaling.minReplicas,
          },
          pollingInterval: 30,
          cooldownPeriod: 300,
          idleReplicaCount: '',
          restoreToOriginalReplicaCount: false,
        },
      },

      // Pod Tolerations
      podTolerations: [],

      // nodeSelector for Pods
      nodeSelector: {
        'kubernetes.io/os': 'linux',
        'letsbuild.com/purpose': 'worker',
        'kubernetes.io/arch': 'amd64',
      },

      // Pod Labels
      podLabels: {
        team: error 'podLabels.team must be set',
        dept: 'product',
        product: 'letsbuild',
        env: s.namespace,
        'app.kubernetes.io/name': common.name,
        'app.kubernetes.io/instance': '%s-%s' % [common.name, s.namespace],
        'app.kubernetes.io/part-of': 'letsbuild',
      },

      // Pod annotation
      podAnnotations: {

      } + (
        if std.objectHas(common.container, 'ports')
        then {
          'prometheus.istio.io/merge-metrics': 'true',
          'prometheus.io/scrape': 'true',
          'prometheus.io/path': '/metrics',
          'prometheus.io/port': std.toString(common.container.ports[0].port),
        }
        else {}
      ),

      // Node Affinity
      nodeAffinity: {
        enabledPreffered: false,
        enabledRequired: false,
        preferred: [],
        required: {
          nodeSelectorTerms: [],
        },
      },

      // Pod Affinity
      podAffinity: {
        enabledPreffered: false,
        enabledRequired: false,
        preferred: [],
        required: [],
      },

      // Pod Anti-Affinity
      podAntiAffinity: {
        enabledPreffered: true,
        enabledRequired: false,
        preferred: [
          {
            weight: 100,
            podAffinityTerm: {
              topologyKey: 'kubernetes.io/hostname',
              labelSelector: {
                matchExpressions: [
                  {
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [
                      common.name,
                    ],
                  },
                ],
              },
            },
          },
        ],
        required: [],
      },

      // Volume mounts functions:
      volumes: [],

      // Main application containrt
      container: {
        local cont = self,

        name: common.name,
        repository: error '_config.deployment.container.repository must be set',
        tag: error '_config.deployment.container.tag must be set',
        image: '%(repository)s:%(tag)s' % { repository: cont.repository, tag: cont.tag },

        imagePullPolicy: 'IfNotPresent',

        resourcesLimits:
          local limit(value) =
            // extract the unit from the value
            local unit = std.slice(value, std.length(value) - 2, std.length(value), 1);
            // return 2x increased value
            2 * std.parseInt(std.rstripChars(value, unit)) + unit;

          if std.objectHas(cont, 'resourcesRequests')
          then {
            cpu: null,
            mem: if std.objectHas(cont.resourcesRequests, 'mem') then limit(cont.resourcesRequests.mem) else null,
          }
          else { cpu: null, mem: null },

        envVars: {
          ENVIRONMENT: s.namespace,
        },
        extraEnvVars: [
                        {
                          name: 'HOST_IP',
                          valueFrom: { fieldRef: { fieldPath: 'status.hostIP' } },
                        },
                        {
                          name: 'POD_IP',
                          valueFrom: { fieldRef: { fieldPath: 'status.podIP' } },
                        },
                        {
                          name: 'OTEL_RESOURCE_ATTRIBUTES',
                          value: 'k8s.pod.ip=$(POD_IP),container=%s' % cont.name,
                        },
                      ]
                      + (
                        // configure .NET garbage collector if ASPNETCORE_ENVIRONMENT is set
                        // set the GCHeapHardLimit to 80% of requested memory
                        if std.objectHas(cont.envVars, 'ASPNETCORE_ENVIRONMENT') && std.objectHas(cont, 'resourcesRequests') && std.objectHas(cont.resourcesRequests, 'mem') then [{
                          name: 'DOTNET_GCHeapHardLimit',
                          value: '%x' % (0.8 * std.parseJson(
                                           if std.endsWith(cont.resourcesRequests.mem, 'Mi') then
                                             std.strReplace(cont.resourcesRequests.mem, 'Mi', '000000')
                                           else if std.endsWith(cont.resourcesRequests.mem, 'Gi') then
                                             std.strReplace(cont.resourcesRequests.mem, 'Gi', '000000000')
                                         )),
                        }]
                        else []
                      ),
        envFrom: [],
      },

      sidecarContainers: [],
      initContainers: [],
    },

    deployment: s.common {
      // overrides specific to deployments
      local depl = self,
    },

    job: s.common {
      // overrides specific to Jobs
      annotations+: {
        // ArgoCD sync settings
        'argocd.argoproj.io/hook': 'Sync',
        'argocd.argoproj.io/hook-delete-policy': 'BeforeHookCreation',
        'argocd.argoproj.io/sync-wave': '-1',
      },
      podAnnotations+: {
        'sidecar.istio.io/inject': 'false',
        'sidecar.istio.io/proxyCPU':: null,
        'sidecar.istio.io/proxyMemory':: null,
      },
    },
    statefulSet: s.common {
      // overrides specific to statefulsets
      local sts = self,

      autoscaling+: {
        scaleTarget+: {
          kind: 'StatefulSet',
        },
      },

    },
    ingress: {
      name: s.name,
      host: error '_config.ingress.host must be set',
      // converting `host` to a list of hosts for backwards compatibility
      hosts: [self.host],
      // Object labels
      labels: {
        'app.kubernetes.io/name': s.name,
        'app.kubernetes.io/instance': '%s-%s' % [s.name, s.namespace],
        'app.kubernetes.io/part-of': 'letsbuild',
      },

      // Object annotations
      annotations: {},
    },
    publicAPI: {
      name: s.name,
      host: 'api.%(envDomain)s' % { envDomain: s.envDomain },
      // converting `host` to a list of hosts for backwards compatibility
      hosts: [self.host],
      paths: ['/'],
      // Object labels
      labels: {
        'app.kubernetes.io/name': s.name,
        'app.kubernetes.io/instance': '%s-%s' % [s.name, s.namespace],
        'app.kubernetes.io/part-of': 'letsbuild',
      },
    },
    aproplanAPI: {
      name: s.name,
      host: 'aproplan-api.%(envDomain)s' % { envDomain: s.envDomain },
      // converting `host` to a list of hosts for backwards compatibility
      hosts: [self.host],
      paths: ['/'],
      // Object labels
      labels: {
        'app.kubernetes.io/name': 'aproplan-%s' % s.name,
        'app.kubernetes.io/instance': 'aproplan-%s-%s' % [s.name, s.namespace],
        'app.kubernetes.io/part-of': 'aproplan',
      },
    },
  },
}
