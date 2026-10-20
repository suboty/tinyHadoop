# Big Data
## Практическая работа №2
## Работа с Apache Flume

---

## Работа с Apache Flume

В этой лабораторной работе вы научитесь использовать Apache Flume для сбора, агрегации и перемещения больших объемов данных из различных источников в локальную файловую систему. Все действия выполняются через командную строку, без использования веб-интерфейсов.

Для удобства мы будем запускать агенты Flume в фоновом режиме, а их логи записывать в файлы. Это позволит нам управлять всем процессом из одного окна терминала.

---

## 1. Простой перенос данных (Netcat to Logger)

Этот агент позволяет генерировать события и последовательно логировать их в консоль (в нашем случае — в лог-файл).

**1.1.** Создайте рабочий каталог и перейдите в него:
```bash
mkdir -p ~/flume
cd ~/flume
```

**1.2.** Создайте файл конфигурации `transfer.conf`:
```bash
nano transfer.conf
```
Добавьте в него следующий текст:
```properties
agent1.sources = netcatSrc
agent1.channels = memChannel
agent1.sinks = log

agent1.sources.netcatSrc.channels = memChannel
agent1.sinks.log.channel = memChannel

agent1.sources.netcatSrc.type = netcat
agent1.sources.netcatSrc.bind = 0.0.0.0
agent1.sources.netcatSrc.port = 3333

agent1.sinks.log.type = logger
agent1.channels.memChannel.type = memory
agent1.channels.memChannel.capacity = 100
```

**1.3.** Запустите агент Flume в фоновом режиме, перенаправив весь вывод в файл `flume_agent1.log`:
```bash
flume-ng agent --name agent1 --conf-file transfer.conf > flume_agent1.log 2>&1 &
```

**1.4.** Убедитесь, что агент запустился, и начните отслеживать его лог в реальном времени. Оставьте эту команду работать:
```bash
tail -f flume_agent1.log
```

**1.5.** Откройте **новый терминал** (для отправки данных) и подключитесь к агенту через `telnet`:
```bash
telnet localhost 3333
```
Введите несколько сообщений (например, `this is a test message`, `Hadoop`, `Spark`). Нажмите Enter после каждого.

**1.6.** Вернитесь в терминал, где работает `tail -f`. Вы увидите, как введенные вами сообщения появились в логах в виде событий (Event). Это означает, что Source успешно принял данные, Channel их буферизировал, а Sink вывел в консоль. Нажмите `Ctrl+C`, чтобы остановить `tail`.

**1.7.** Закройте `telnet`, нажав `Ctrl+]`, а затем введя команду `close`. Остановите фоновый процесс Flume:
```bash
pkill -f "agent1"
```

---

## 2. Базовый перенос данных через буферную директорию

Агент `agent2` будет использоваться для мониторинга директории. Любые файлы, попадающие в буферную директорию (spool), будут автоматически перемещаться в целевую директорию.

**2.1.** Создайте файл конфигурации `transfer_spool.conf`:
```bash
nano transfer_spool.conf
```
Добавьте в него:
```properties
agent2.sources = dirSrc
agent2.channels = memChannel
agent2.sinks = fileSink

agent2.sources.dirSrc.channels = memChannel
agent2.sinks.fileSink.channel = memChannel

agent2.sources.dirSrc.type = spoolDir
agent2.sources.dirSrc.spoolDir = /home/student/flume/incoming

agent2.sinks.fileSink.type = file_roll
agent2.sinks.fileSink.sink.directory = /home/student/flume/output
agent2.sinks.fileSink.sink.rollInterval = 0

agent2.channels.memChannel.type = memory
agent2.channels.memChannel.capacity = 100
```

**2.2.** Создайте необходимые папки для работы агента (если они еще не созданы):
```bash
mkdir -p /home/student/flume/incoming
mkdir -p /home/student/flume/output
```

**2.3.** Запустите агент `agent2` в фоновом режиме:
```bash
flume-ng agent --name agent2 --conf-file transfer_spool.conf > flume_agent2.log 2>&1 &
```

**2.4.** Запустите отслеживание лога:
```bash
tail -f flume_agent2.log
```

**2.5.** Откройте **новое окно терминала**. Скрипт подготовки сгенерировал для вас множество файлов. Скопируем несколько из них в буферную директорию, чтобы Flume их увидел:
```bash
cd /home/student/flume/incoming

# Копируем 5 файлов с текстом "Алисы"
cp /home/student/Data/generated/alice_copy_1.txt .
cp /home/student/Data/generated/alice_copy_2.txt .
cp /home/student/Data/generated/alice_copy_3.txt .
cp /home/student/Data/generated/alice_copy_4.txt .
cp /home/student/Data/generated/alice_copy_5.txt .

# Копируем 2 кастомных файла
cp /home/student/Data/generated/custom_file_1.txt .
cp /home/student/Data/generated/custom_file_2.txt .
```

**2.6.** Вернитесь в терминал с `tail -f`. Вы увидите сообщения о том, что Flume обнаружил новые файлы и переместил их (добавив расширение `.COMPLETED`). Нажмите `Ctrl+C`.

**2.7.** Проверьте целевую директорию. Файлы должны появиться там:
```bash
ls -l /home/student/flume/output/
```
Остановите `agent2`:
```bash
pkill -f "agent2"
```

---

## 3. Использование Перехватчика (Interceptor)

Агент `agent3` будет перехватывать события и автоматически добавлять в их заголовки IP-адрес (или имя) хоста.

**3.1.** Создайте файл конфигурации `interceptor.conf`:
```bash
nano interceptor.conf
```
Добавьте в него:
```properties
agent3.sources = netcatSrc
agent3.channels = memChannel
agent3.sinks = log

agent3.sources.netcatSrc.channels = memChannel
agent3.sinks.log.channel = memChannel

agent3.sources.netcatSrc.type = netcat
agent3.sources.netcatSrc.bind = 0.0.0.0
agent3.sources.netcatSrc.port = 3333

agent3.sinks.log.type = logger
agent3.channels.memChannel.type = memory
agent3.channels.memChannel.capacity = 100

agent3.sources.netcatSrc.interceptors = i1
agent3.sources.netcatSrc.interceptors.i1.type = host
agent3.sources.netcatSrc.interceptors.i1.hostHeader = hostname
```

**3.2.** Запустите `agent3` в фоне:
```bash
flume-ng agent --name agent3 --conf-file interceptor.conf > flume_agent3.log 2>&1 &
```

**3.3.** Запустите отслеживание лога:
```bash
tail -f flume_agent3.log
```

**3.4.** В новом терминале подключитесь через `telnet`:
```bash
telnet localhost 3333
```
Введите сообщение, например: `This is testing Flume with interceptor. Hadoop Spark`.

**3.5.** Вернитесь в терминал с `tail -f`. В логах вы увидите, что к событию добавлен заголовок `hostname` (со значением `localhost` или `127.0.0.1`). Это подтверждает, что Interceptor сработал. Нажмите `Ctrl+C` и остановите агент:
```bash
pkill -f "agent3"
```

---

## 4. Создайте новый поток данных «с нуля»

В этом задании вам нужно самостоятельно написать конфигурацию для агента `agent4`.

| Параметр | Значение |
| :--- | :--- |
| **Source Type** | `netcat` |
| **Source Bind** | `localhost` |
| **Source Port** | `11111` |
| **Channel Type** | `file` (File Channel) |
| **Channel Capacity** | `1000` |
| **Channel Transaction Capacity** | `100` |
| **Sink Type** | `logger` |

**4.1.** Создайте файл конфигурации `my_flow.conf` и напишите его самостоятельно, опираясь на примеры выше.
> **Подсказка:** Для File Channel потребуется указать директории для хранения данных канала (свойства `checkpointDir` и `dataDirs`). Создайте для них отдельную папку (например, `mkdir ~/flume/filechannel`).

**4.2.** Запустите агент в фоне и запустите `tail -f` на его лог:
```bash
flume-ng agent --name agent4 --conf-file my_flow.conf > flume_agent4.log 2>&1 &
tail -f flume_agent4.log
```

**4.3.** В другом окне терминала запустите `telnet` и подключитесь к порту `11111`. Отправьте сообщение `Hello world!` и убедитесь, что оно появилось в логах агента.

**4.4.** Нажмите `Ctrl+C` в терминале с логами и остановите агент:
```bash
pkill -f "agent4"
```
