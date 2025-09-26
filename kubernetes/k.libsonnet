(import 'github.com/jsonnet-libs/k8s-libsonnet/1.31/main.libsonnet') + {
  core+: {
    v1+: {
      volume+: {
        fromEphemeral(name, ephemeral={})::
          super.withName(name) +
          super.ephemeral.volumeClaimTemplate.metadata.withLabels(if std.objectHas(ephemeral.metadata, 'labels') then ephemeral.metadata.labels else {}) +
          super.ephemeral.volumeClaimTemplate.spec.resources.withRequests(ephemeral.spec.resources.requests) +
          super.ephemeral.volumeClaimTemplate.spec.withAccessModes(if std.objectHas(ephemeral.spec, 'accessModes') then ephemeral.accessModes else ['ReadWriteOnce']) +
          super.ephemeral.volumeClaimTemplate.spec.withStorageClassName(if std.objectHas(ephemeral.spec, 'storageClassName') then ephemeral.storageClassName else 'gp3'),
      },
    },
  },
}
