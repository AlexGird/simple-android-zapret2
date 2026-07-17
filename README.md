# simple-android-zapret2
zapret2 aarch64 android

Скрипт `zapret2.sh` управляет запуском `nfqws2` на Android с root-доступом.

Для управления используется короткая команда:

```sh
zapret2 <команда>
```

Например:

```sh
zapret2 start
zapret2 stop
zapret2 restart
zapret2 status
```

## Требования

- Android с root-доступом;
- Termux;
- рабочая команда `su`;
- поддержка `iptables`;
- поддержка `NFQUEUE` в ядре Android;
- бинарный файл `nfqws2` для Android ARM64;
- Lua-файлы zapret2.

Проверить наличие NFQUEUE можно командой:

```sh
su -c "cat /proc/net/netfilter/nfnetlink_queue"
```

Пустой вывод без ошибки означает, что интерфейс NFQUEUE доступен, но в данный момент к очереди не подключён процесс.

## Структура каталогов

В примерах zapret2 установлен в:

```text
/data/local/zapret2/
```

Рекомендуемая структура:

```text
/data/local/zapret2/
├── bin/
│   └── nfqws2
├── lua/
│   ├── zapret-lib.lua
│   ├── zapret-antidpi.lua
│   └── zapret-auto.lua
├── log/
│   └── nfqws2.log
└── zapret2.sh
```

Каталог можно изменить. Для этого необходимо изменить переменную `BASE` внутри `zapret2.sh`:

```sh
BASE="/data/local/zapret2"
```

Например, для установки в `/data/adb/zapret2`:

```sh
BASE="/data/adb/zapret2"
```

Не рекомендуется размещать исполняемые файлы в `/sdcard`, поскольку файловая система Android может запрещать их выполнение.

## Подготовка файлов

Создайте каталоги:

```sh
su -c "mkdir -p /data/local/zapret2/bin"
su -c "mkdir -p /data/local/zapret2/lua"
su -c "mkdir -p /data/local/zapret2/log"
```

Скопируйте бинарный файл:

```text
nfqws2 → /data/local/zapret2/bin/nfqws2
```

Скопируйте Lua-файлы:

```text
zapret-lib.lua     → /data/local/zapret2/lua/zapret-lib.lua
zapret-antidpi.lua → /data/local/zapret2/lua/zapret-antidpi.lua
zapret-auto.lua    → /data/local/zapret2/lua/zapret-auto.lua
```

Назначьте права на выполнение:

```sh
su -c "chmod 755 /data/local/zapret2/bin/nfqws2"
su -c "chmod 755 /data/local/zapret2/zapret2.sh"
```

## Установка `zapret2.sh`

Если файл находится в домашнем каталоге Termux:

```sh
su -c "cp /data/data/com.termux/files/home/zapret2.sh /data/local/zapret2/zapret2.sh"
su -c "chmod 755 /data/local/zapret2/zapret2.sh"
```

Проверить прямой запуск:

```sh
su -c "/data/local/zapret2/zapret2.sh status"
```

## Создание команды `zapret2`

Чтобы не писать полный путь и `su -c` каждый раз, создайте команду-обёртку в Termux:

```sh
cat > "$PREFIX/bin/zapret2" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh

case "$1" in
    start|stop|restart|status)
        exec su -c "/data/local/zapret2/zapret2.sh $1"
        ;;
    *)
        echo "Использование: zapret2 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
```

Назначьте права и исполняемость:

```sh
chmod 755 "$PREFIX/bin/zapret2"
chmod +x $PREFIX/bin/zapret2
```

После этого команда доступна из Termux:

```sh
zapret2 start
```

Она эквивалентна:

```sh
su -c "/data/local/zapret2/zapret2.sh start"
```

При выполнении:

```sh
zapret2 start
```

значение `$1`:

```text
start
```

При выполнении:

```sh
zapret2 status
```

значение `$1`:

```text
status
```

Обёртка передаёт этот аргумент основному скрипту:

```sh
su -c "/data/local/zapret2/zapret2.sh $1"
```

## Команды управления

### Запуск

```sh
zapret2 start
```

Команда:

1. проверяет наличие `nfqws2`;
2. проверяет наличие Lua-файлов;
3. удаляет старые правила и процессы;
4. добавляет правила `iptables`;
5. запускает `nfqws2`;
6. записывает PID процесса;
7. проверяет, что процесс продолжает работать.

### Остановка

```sh
zapret2 stop
```

Команда:

1. удаляет правила NFQUEUE из `iptables`;
2. останавливает процесс `nfqws2`;
3. удаляет PID-файл.

### Перезапуск

```sh
zapret2 restart
```

Эквивалентно последовательному выполнению:

```sh
zapret2 stop
zapret2 start
```

### Проверка состояния

```sh
zapret2 status
```

Команда показывает:

- правила NFQUEUE в `iptables`;
- процесс `nfqws2`;
- состояние очереди NFQUEUE;
- последние строки журнала.

## Ручной запуск без обёртки

Все команды можно выполнять напрямую:

```sh
su -c "/data/local/zapret2/zapret2.sh start"
su -c "/data/local/zapret2/zapret2.sh stop"
su -c "/data/local/zapret2/zapret2.sh restart"
su -c "/data/local/zapret2/zapret2.sh status"
```

## Удаление

Сначала остановите zapret2:

```sh
zapret2 stop
```

Удалите команду Termux:

```sh
rm -f "$PREFIX/bin/zapret2"
```

Удалите каталог:

```sh
su -c "rm -rf /data/local/zapret2"
```

## Примечание

Текущая конфигурация с цепочкой `OUTPUT` обрабатывает трафик приложений самого Android-устройства.

Для обработки трафика устройств, подключённых через точку доступа Android, могут дополнительно потребоваться правила в цепочках:

```text
PREROUTING
FORWARD
POSTROUTING
```

Такие правила зависят от прошивки, интерфейсов мобильной сети и Wi-Fi, а также от используемой схемы маршрутизации.
