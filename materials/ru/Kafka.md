# Big Data
## Практическая работа №3
## Работа с Kafka

---

В этой лабораторной работе вы научитесь настраивать конвейер потоковой передачи данных. Мы будем использовать Kafka для приема сообщений, Apache Flume для их извлечения и сохранения в HDFS. Все действия выполняются в командной строке.

Для удобства мы будем запускать все фоновые процессы и отслеживать их логи из одного окна терминала, используя перенаправление вывода в файлы.

---

## 1. Настройка и запуск Apache Kafka

В вашей среде уже установлен Apache Kafka. Нам нужно запустить его сервер (брокер) в фоновом режиме.

**1.1.** Войдите как пользователь `root` и перейдите в директорию с Kafka (`~/tinyHadoop/kafka`):
```bash
su - root
cd ~/tinyHadoop/kafka
```

**1.2.** Запустите сервер Kafka в фоновом режиме, перенаправив его логи в файл `kafka.log`:
```bash
bin/kafka-server-start.sh config/server.properties > kafka.log 2>&1 &
```

**1.3.** Подождите несколько секунд, пока Kafka запустится, и проверьте лог:
```bash
tail -n 20 kafka.log
```
Если вы видите сообщения о старте брокера (например, `started (kafka.server.KafkaServer)`), значит, всё работает.

**1.4.** Создайте топик `stream_text`, в который будут отправляться данные:
```bash
bin/kafka-topics.sh --create --topic stream_text --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1
```
Вы должны увидеть сообщение `Created topic stream_text`.

---

## 2. Запуск Kafka-продюсера

Поскольку продюсер (источник данных) уже предустановлен в системе, мы просто запустим его в фоне. Он будет читать файл «Алиса в стране чудес» и отправлять строки в топик `stream_text`.

**2.1.** Войдите как пользователь `student` и запустите скрипт продюсера в фоновом режиме:
```bash
python3.14 /mnt/kafka_producer.py > producer.log 2>&1 &
```

**2.2.** Отслеживайте работу продюсера через лог:
```bash
tail -f producer.log
```
Вы увидите, как в логе появляются строки `Sent: ...` — это значит, что данные уходят в Kafka. Нажмите `Ctrl+C`, чтобы остановить просмотр лога (сам скрипт продолжит работать в фоне).

---

## 3. Подготовка HDFS

Теперь подготовить HDFS к принятию данных из Kafka. Переключимся в пользователя `hadoop`:
```bash
su - hadoop
```

Выключите у HDFS безопасный режим работы (запрещает изменения в ФС):
```bash
hdfs dfsadmin -safemode leave
```

Создайте директорию (`/user/student/kafka_data`) для пользователя `student`:
```bash
hdfs dfs -mkdir /user/student/kafka_data
```

Передайте права на директорию пользователю `student`:
```bash
hdfs dfs -chown student /user/student/kafka_data
```

Переключитесь обратно в пользователя `student`:
```bash
su - student
```

---

## 4. Настройка Flume для перенаправления данных в HDFS

Теперь настроим Flume так, чтобы он забирал данные из топика Kafka и сохранял их в HDFS.

**4.1.** Создайте конфигурационный файл для Flume:
```bash
nano ~/flume/kafka-to-hdfs.conf
```
Добавьте в него следующие настройки:
```properties
agent.sources = kafkaSource
agent.sinks = hdfsSink
agent.channels = memChannel

agent.sources.kafkaSource.type = org.apache.flume.source.kafka.KafkaSource
agent.sources.kafkaSource.channels = memChannel
agent.sources.kafkaSource.kafka.bootstrap.servers = localhost:9092
agent.sources.kafkaSource.kafka.topics = stream_text
agent.sources.kafkaSource.kafka.consumer.group.id = flume-consumer-group

agent.sinks.hdfsSink.type = hdfs
agent.sinks.hdfsSink.channel = memChannel
agent.sinks.hdfsSink.hdfs.path = /user/student/kafka_data/
agent.sinks.hdfsSink.hdfs.filePrefix = alice-
agent.sinks.hdfsSink.hdfs.fileType = DataStream
agent.sinks.hdfsSink.hdfs.writeFormat = Text
agent.sinks.hdfsSink.hdfs.rollInterval = 10
agent.sinks.hdfsSink.hdfs.rollSize = 0
agent.sinks.hdfsSink.hdfs.rollCount = 0

agent.channels.memChannel.type = memory
agent.channels.memChannel.capacity = 10000
agent.channels.memChannel.transactionCapacity = 1000
```

**4.2.** Запустите агент Flume в фоне:
```bash
flume-ng agent --name agent --conf /opt/flume/conf --conf-file ~/flume/kafka-to-hdfs.conf > flume_hdfs.log 2>&1 &
```

**4.3.** Отслеживайте работу Flume:
```bash
tail -f flume_hdfs.log
```
Вы должны увидеть сообщения о том, что Flume подключился к Kafka и начал обрабатывать события. Нажмите `Ctrl+C`, чтобы остановить просмотр.

---

## 5. Проверка результата в HDFS

**5.1.** Подождите около 10–20 секунд (Flume настроен на создание файла в HDFS каждые 10 секунд: `rollInterval = 10`).

**5.2.** Переключитесь на пользователя `hadoop` и проверьте содержимое HDFS:
```bash
su - hadoop
hdfs dfs -ls /user/student/kafka_data/
```
Вы должны увидеть файлы с префиксом `alice-`.

**5.3.** Посмотрите содержимое одного из файлов, чтобы убедиться, что данные дошли:
```bash
hdfs dfs -cat /user/student/kafka_data/alice-* | head -n 20
```
Вы должны увидеть строки из книги «Алиса в стране чудес».

---

## 6. Остановка всех служб

Переключитесь в пользователя `student`:
```bash
su - student
```

После завершения работы остановите все фоновые процессы:
```bash
pkill -f kafka.Kafka
pkill -f org.apache.flume.node.Application
pkill -f kafka_producer.py
```
Убедитесь, что процессов не осталось:
```bash
jps
```
В выводе не должно быть `Application` или `Kafka`.
