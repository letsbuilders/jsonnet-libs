(import 'github.com/jsonnet-libs/k8s-libsonnet/1.31/main.libsonnet') + {
  core+: {
    v1+: {
      volume+: {
        fromEphemeral(name, ephemeral={})::
          super.withName(name) +
          super.ephemeral.volumeClaimTemplate.spec.resources.withRequests(ephemeral.resources.requests) +
          super.ephemeral.volumeClaimTemplate.spec.withAccessModes(if std.objectHas(ephemeral, 'accessModes') then ephemeral.accessModes else ['ReadWriteOnce']) +
          super.ephemeral.volumeClaimTemplate.spec.withStorageClassName(if std.objectHas(ephemeral, 'storageClassName') then ephemeral.storageClassName else 'gp3'),
      },
    },
  },
}
