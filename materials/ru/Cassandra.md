# Big Data
## Практическая работа №4
## Работа с Apache Cassandra

---

В этой лабораторной работе вы начнете использовать Cassandra для работы с NoSQL-данными.

---

## 1. Проверка Cassandra NoSQL

Если вы выполнили скрипт `prepare-cassandra.sh`, то Cassandra должна быть уже установлена и запущена. 

**1.1.** Проверьте статус службы:
```bash
sudo systemctl status cassandra
```
Служба должна быть в состоянии `active (running)`.

---

## 2. Запуск CQL shell

**2.1.** Запустите CQL shell:
```bash
cqlsh
```

Если оболочка не запускается, то попробуйте запустить её напрямую:
```bash
/opt/cassandra/bin/cqlsh
```

**2.2.** Выведите список всех пространств ключей (keyspaces) в кластере:
```sql
desc keyspaces;
```

**2.3.** Создайте пространство ключей с именем `ks_work1` на одном узле:
```sql
CREATE KEYSPACE ks_work1
WITH REPLICATION = {
    'class': 'SimpleStrategy',
    'replication_factor' : 1
};
```

**2.4.** (Информационно) Если вы хотите использовать несколько центров обработки данных, используйте `NetworkTopologyStrategy`.

**2.5.** Создайте пространство ключей `ks_work2`:
```sql
CREATE KEYSPACE ks_work2
WITH REPLICATION = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1' : 1
};
```

**2.6.** Проверьте сгенерированную информацию о пространстве ключей:
```sql
describe keyspace ks_work1;
desc ks_work2;
```

**2.7.** Изменение и удаление параметров пространства ключей:
```sql
alter keyspace ks_work2 with durable_writes = false;
desc ks_work2;
```
Проверьте измененный параметр `durable_writes = false`.
```sql
drop KEYSPACE ks_work2;
desc ks_work2;
```
Убедитесь, что пространство ключей `ks_work2` удалено.

---

## 3. Доступ к данным с помощью DDL

**3.1.** Создайте таблицу со следующими характеристиками (без команды `use`):
*   Keyspace: `ks_work1`
*   Table name: `user_info`
*   Column name: `id uuid, l_name text, f_name text, country text, birth int, gender text`
*   Partition Key: `id`

```sql
create table ks_work1.user_info (id uuid primary key, l_name text, f_name text, country text, birth int, gender text);
```

**3.2.** Проверьте таблицу `user_info`:
```sql
desc tables;
```

**3.3.** Создайте еще одну таблицу:
*   Table name: `user_info2`
*   Column name: `id int, l_name text, f_name text, country text, birth text, gender text, s text, num int`
*   static column: `s`
*   primary key: `country, birth, id`
*   composite partition key: `country, birth`

```sql
create table ks_work1.user_info2 (id int, l_name text, f_name text, country text, birth text, gender text, s text static, num int, primary key((country,birth), id));
desc tables;
```

**3.4.** Проверьте таблицу `user_info2`.

**3.5.** Следующая таблица:
*   Keyspace: `ks_work1`
*   Table name: `user_info3`
*   Column name: `id int, l_name text, f_name text, country text, birth int, age int`
*   Compound Primary Key: `country, id, birth`
*   Clustering key: `birth`

```sql
create table ks_work1.user_info3 (id int, l_name text, f_name text, country text, birth int, gender text, s text static, num int, primary key(country, id, birth));
```

**3.6.** Еще одна таблица:
*   Keyspace: `ks_work1`
*   Table name: `user_info33`
*   Column name: `id int, l_name text, f_name text, country text, birth int, age int`
*   Compound Primary Key: `country, id, birth` (descending order)
*   Clustering key: `birth` (store data in descending order)

```sql
create table ks_work1.user_info33 (id int, l_name text, f_name text, country text, birth int, gender text, s text static, age int, primary key(id, birth)) with clustering order by (birth desc);
desc tables;
```

**3.7.** Измените пространство ключей на `ks_work1` и проверьте таблицы:
```sql
use ks_work1;
desc tables;
desc user_info;
```

**3.8.** Добавьте столбец в таблицу `user_info33` и проверьте её:
*   Column name: `height`, type `int`

```sql
alter table user_info33 add height int;
desc user_info33;
```

**3.9.** Удалите таблицу `user_info33`:
```sql
drop table user_info33;
```

**3.10.** Еще раз перечислите все таблицы, чтобы убедиться, что `user_info33` удалена:
```sql
desc tables;
```

**3.11.** Введите данные в таблицы `user_info2` и `user_info3` (пример для первой строки):
```sql
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('KOR', '1995', 1, 'value8', 'jason', 'M', 'jeong', 18);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('KOR', '1995', 5, 'value8', 'lonan', 'M', 'jeong', 53);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('KOR', '1995', 8, 'value8', 'kim', 'F', 'null', 61);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('USA', '1967', 3, 'value6', 'scitt', 'M', 'jeong', 32);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('USA', '1967', 6, 'value6', 'angela', 'F', 'park', 25);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('JPN', '1974', 4, 'value4', 'jane', 'F', 'null', null);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('USA', '1985', 2, 'value2', 'tommy', 'M', 'park', 19);
INSERT INTO user_info2(country, birth, id, s, f_name, gender, l_name, num) VALUES ('CAN', '1994', 7, 'value7', 'bella', 'F', 'null', 41);

INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('CAN', 7, 1994, 'value7', 'bella', 'F', 'null', 41);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('KOR', 1, 1995, 'value8', 'jason', 'M', 'jeong', 18);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('KOR', 5, 1995, 'value8', 'lonan', 'M', 'jeong', 53);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('KOR', 8, 1995, 'value8', 'kim', 'F', 'null', 61);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('USA', 2, 1985, 'value6', 'tommy', 'M', 'park', 19);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('USA', 3, 1967, 'value6', 'scitt', 'M', 'jeong', 32);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('USA', 6, 1967, 'value6', 'angela', 'F', 'park', 25);
INSERT INTO user_info3(country, id, birth, s, f_name, gender, l_name, num) VALUES ('JPN', 4, 1974, 'value4', 'jane', 'F', 'null', null);
```

---

## 4. Доступ к данным с помощью DML

**4.1.** Выведите данные из `user_info2` и `user_info3` с ограничением в 1 строку на секцию:
```sql
select * from user_info2;
select * from user_info3;
select * from user_info2 per partition limit 1;
select * from user_info3 per partition limit 1;
```

**4.2.** Список лиц, включенных в `KOR`/`JPN`:
```sql
select f_name, l_name from user_info3 where country in ('KOR', 'JPN');
```

**4.3.** Найдите общее количество записей, а также сумму, минимальное и среднее значения поля `num`:
```sql
select count(id) as count, sum(num) as sum, min(num) as min, avg(num) as avg from user_info3;
```

**4.4.** Получите запись о стране `KOR`:
```sql
select * from user_info3 where country='KOR';
```

**4.5.** Поиск записей, где страна `KOR` и `num` больше 30:
```sql
select * from user_info3 where country='KOR' and num > 30 allow filtering;
```

**4.6.** Измените значение `s` в `KOR` на `'value_new'` и сделайте его пустым через 30 секунд (используя TTL):
```sql
update user_info3 using ttl 30 set s='value_new' where country='KOR';
select * from user_info3;
```
*(Через 30 секунд значения в столбце `s` для строк `KOR` станут `null`).*

**4.7.** Обновите строку в таблице `user_info3`, где `id` равен 4:
```sql
insert into user_info3 (id, f_name, l_name, num, country, birth) values(4,'ann','kim', 85, 'JPN', '1974');
```

**4.8.** Измените значение `f_name` в записи с `id` 3 на "scott":
```sql
insert into user_info3 (id, l_name, f_name, country, birth, gender, s, num) values (3,'jeong','scott','USA','1967', 'M', 'value3', 32) if not exists;
```

**4.9.** Удаление столбца `s`, где страна `USA`:
```sql
delete s from user_info3 where country='USA';
select * from user_info3;
```

**4.10.** Удаление строк, где указана страна `CAN` или `JPN`:
```sql
delete from user_info3 where country in ('CAN', 'JPN');
select * from user_info3;
```

---

## Самостоятельная работа

**1. Напишите команду для создания таблицы `country`:**

**1.1.** Создайте таблицу со следующими условиями:
*   `id` (uuid) — Primary Key
*   `name` (text) — Partition Key
*   `capital` (text) — Partition Key
*   `population` (int)

**1.2.** Введите следующие значения в созданную таблицу:
| id | Name | Capital | Population |
| :--- | :--- | :--- | :--- |
| 1 | USA | Washington D.C. | 333 098 437 |
| 2 | Germany | Berlin | 84 073 352 |
| 3 | France | Paris | 65 426 179 |

**2. Работа с запросами:**

**2.1.** Запросите из таблицы стран следующую информацию:
*   Население Кореи
*   Население и столицы всех стран в таблице
*   Страны с населением менее 100 000 000 человек
*   Страны с населением от 50 до 100 миллионов человек

**2.2.** Создайте запросы к таблице стран со следующей информацией:
*   Назовите страну с наименьшим населением
*   Выведите первую строку в таблице стран
*   Сколько стран указано в таблице?
