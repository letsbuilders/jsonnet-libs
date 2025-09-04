local redis(params) = (import 'main.libsonnet') + {
  _config+: params,
};

{
  redis:: redis,
}
