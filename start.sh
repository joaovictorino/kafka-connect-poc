docker run -d \
    --net=host \
    --name=zookeeper \
    -e ZOOKEEPER_CLIENT_PORT=2181 \
    -e ZOOKEEPER_TICK_TIME=2000 \
    confluentinc/cp-zookeeper:6.2.0

docker run -d \
    --net=host \
    --name=kafka \
    -e KAFKA_ZOOKEEPER_CONNECT=localhost:2181 \
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
    confluentinc/cp-kafka:6.2.0

docker run -d \
  --net=host \
  --name=schema-registry \
  -e SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL=localhost:2181 \
  -e SCHEMA_REGISTRY_HOST_NAME=localhost \
  -e SCHEMA_REGISTRY_LISTENERS=http://localhost:8081 \
  confluentinc/cp-schema-registry:6.2.0

docker run \
  --net=host \
  --rm \
  confluentinc/cp-kafka:6.2.0 \
  kafka-topics --create --topic quickstart-avro-offsets --partitions 1 --replication-factor 1 --config cleanup.policy=compact --if-not-exists --zookeeper localhost:2181

docker run \
  --net=host \
  --rm \
  confluentinc/cp-kafka:6.2.0 \
  kafka-topics --create --topic quickstart-avro-config --partitions 1 --replication-factor 1 --config cleanup.policy=compact --if-not-exists --zookeeper localhost:2181

docker run \
  --net=host \
  --rm \
  confluentinc/cp-kafka:6.2.0 \
  kafka-topics --create --topic quickstart-avro-status --partitions 1 --replication-factor 1 --config cleanup.policy=compact --if-not-exists --zookeeper localhost:2181

docker run \
   --net=host \
   --rm \
   confluentinc/cp-kafka:6.2.0 \
   kafka-topics --describe --zookeeper localhost:2181

docker run -d \
  --name=kafka-connect-avro \
  --net=host \
  -e CONNECT_BOOTSTRAP_SERVERS=localhost:9092 \
  -e CONNECT_REST_PORT=8083 \
  -e CONNECT_GROUP_ID="quickstart-avro" \
  -e CONNECT_CONFIG_STORAGE_TOPIC="quickstart-avro-config" \
  -e CONNECT_OFFSET_STORAGE_TOPIC="quickstart-avro-offsets" \
  -e CONNECT_STATUS_STORAGE_TOPIC="quickstart-avro-status" \
  -e CONNECT_KEY_CONVERTER="io.confluent.connect.avro.AvroConverter" \
  -e CONNECT_VALUE_CONVERTER="io.confluent.connect.avro.AvroConverter" \
  -e CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL="http://localhost:8081" \
  -e CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL="http://localhost:8081" \
  -e CONNECT_INTERNAL_KEY_CONVERTER="org.apache.kafka.connect.json.JsonConverter" \
  -e CONNECT_INTERNAL_VALUE_CONVERTER="org.apache.kafka.connect.json.JsonConverter" \
  -e CONNECT_REST_ADVERTISED_HOST_NAME="localhost" \
  -e CONNECT_LOG4J_ROOT_LOGLEVEL=DEBUG \
  -v /home/joao/source/kafka/quickstart/file:/tmp/quickstart \
  -v /home/joao/source/kafka/quickstart/jars:/etc/kafka-connect/jars \
  confluentinc/cp-kafka-connect:6.2.0

docker run -d \
  --name=quickstart-mysql \
  --network=kafka_default \
  -e MYSQL_ROOT_PASSWORD=confluent \
  -e MYSQL_USER=confluent \
  -e MYSQL_PASSWORD=confluent \
  -e MYSQL_DATABASE=connect_test \
  -p 3306:3306 \
  mysql:8.0

  docker exec -it quickstart-mysql bash

  mysql -u confluent -p

curl -X POST -H "Content-Type: application/json" --data '{ "name": "quickstart-jdbc-source", "config": { "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector", "tasks.max": 1, "connection.url": "jdbc:mysql://172.18.0.6:3306/connect_test?user=root&password=confluent", "mode": "incrementing", "incrementing.column.name": "id", "timestamp.column.name": "modified", "topic.prefix": "quickstart-jdbc-", "poll.interval.ms": 1000 } }' http://localhost:8083/connectors
curl -X POST -H "Content-Type: application/json" --data '{ "name": "quickstart-jdbc-sink", "config": { "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector", "tasks.max": 1, "connection.url": "jdbc:mysql://172.18.0.6:3306/result?user=root&password=confluent", "topics":"quickstart-jdbc-test", "auto.create": "true" } }' http://localhost:8083/connectors

curl -X POST -H "Content-Type: application/json" --data '{"name": "quickstart-avro-file-sink", "config": {"connector.class":"org.apache.kafka.connect.file.FileStreamSinkConnector", "tasks.max":"1", "topics":"quickstart-jdbc-test", "file": "/tmp/quickstart/jdbc-output.txt"}}' http://localhost:8083/connectors