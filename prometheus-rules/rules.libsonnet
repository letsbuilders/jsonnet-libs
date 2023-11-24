local rules(name, rules, labels='operations') = {
  apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        labels: labels,
        name: name,
      },
      spec: {
        groups: rules,
      },
};

{
  rules:: rules,
}