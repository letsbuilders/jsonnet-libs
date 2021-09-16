/*
This module is a collection of auxiliary init containers
*/


local waitForPortImage = '783314667363.dkr.ecr.eu-west-1.amazonaws.com/k8s-aux/wait-for-port:latest';

local waitForPostgres = function(secretName, timeout='300000') {
  name: 'wait-for-postgres',
  image: waitForPortImage,
  command: ['/usr/local/bin/wait-port', '--wait-for-dns', '-t', '3000', '$(PGHOST):$(PGPORT)'],
   // PGHOST and PGPORT are stored in the secret
  envFrom+: [ { secretRef: { name: secretName } } ]
};

local waitForKafka = function(timeout='300000') {
  name: 'wait-for-kafka',
  image: waitForPortImage,
  command: ['/usr/local/bin/wait-port', '--wait-for-dns', '-t', timeout, '$(KAFKA_SERVERS)'],
  envVars: {
    // Kafka connection endpoint is the same for all environments
    KAFKA_SERVERS: 'kafka-kafka-brokers:9092',
  }
};

local waitForSchemaRegistry = function(timeout='300000') {
  name: 'wait-for-schema-registry',
  image: waitForPortImage,
  command: ['/usr/local/bin/wait-port', '--wait-for-dns', '-t', timeout, '$(KAFKA_SCHEMA_REGISTRY_URL)'],
  envVars: {
    // Schema Registry URL is the same for all environments
    KAFKA_SCHEMA_REGISTRY_URL: 'http://confluentic-cp-schema-registry:8081',
  }
};

local waitForPort = function(timeout='300000', target) {
  name: 'wait-for-port',
  image: waitForPortImage,
  command: ['/usr/local/bin/wait-port', '--wait-for-dns', '-t', timeout, target],
};

{
  waitForPostgres:: waitForPostgres,
  waitForKafka:: waitForKafka,
  waitForSchemaRegistry:: waitForSchemaRegistry,
  waitForPort:: waitForPort,
}
