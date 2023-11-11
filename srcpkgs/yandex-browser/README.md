### Установка

Склонировать `void-packages` и установить окружение для сборки пакетов:
```
$ git clone https://github.com/void-linux/void-packages.git
$ cd void-packages
$ ./xbps-src binary-bootstrap
```

Чтобы собрать пакет с пометкой "restricted":
```
$ echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
```

Клонируем репозиторий:
```
$ cd srcpkgs
$ git clone https://gitlab.com/vsyr89/yandex-browser.git
$ cd ../
```

Собираем Яндекс Браузер:
```
$ ./xbps-src pkg yandex-browser
```

Устанавливаем Яндекс Браузер:
```
# xbps-install -v --repository hostdir/binpkgs/nonfree yandex-browser
```
