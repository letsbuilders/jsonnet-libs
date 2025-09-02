local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local secret = k.core.v1.secret;

{
  local c = $._config,
  secret:
    secret.new(c._name, {
      'redis-password': std.base64(c.auth.password),
    }) +
    secret.metadata.withLabels(c.commonLabels),
}
