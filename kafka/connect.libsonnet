local mongoConnector =
  function(
    name,
    topicPrefix,
    database,
    collection,
    environment,
    clusterName='kafka',
    secretName='kafkaconnect-mongodb'
  ) {
    apiVersion: 'kafka.strimzi.io/v1alpha1',
    kind: 'KafkaConnector',
    metadata: {
      name: name,
      labels: {
        'strimzi.io/cluster': clusterName,
      },
    },
    spec: {
      class: 'com.mongodb.kafka.connect.MongoSourceConnector',
      tasksMax: 1,
      config: {
        'topic.prefix': topicPrefix,
        'connection.uri': '${file:/opt/kafka/external-configuration/' + secretName + '/mongo.properties:connection.uri}',
        name: name,
        database: database,
        collection: collection,
      },
    },
  };

{
  mongoConnector:: mongoConnector,
}
