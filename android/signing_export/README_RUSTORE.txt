RuStore AAB: архив с закрытым ключом подписи приложения
======================================================

ВАЖНО
------
1) Закрытый ключ НЕ помещают внутрь файла AAB. AAB подписывается отдельным
   «ключом загрузки» (upload). Консоль RuStore: шаги как в документации
   https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication/new-version-app/upload-aab

2) «Закрытый ключ в архиве» для RuStore делается утилитой PEPK (pepk.jar):
   в ZIP попадает ключ подписи приложения в ЗАШИФРОВАННОМ виде для магазина,
   плюс обычно сертификат (--include-cert). Пароль от кейстора вводите вручную
   в терминале при запуске PEPK.

3) PEM сертификат ключа ЗАГРУЗКИ (открытая часть) создаёте командой keytool
   -exportcert (см. ниже). Его загружаете в RuStore вместе с pepk_out.zip.

Новый keystore с нуля (после удаления старых файлов)
-----------------------------------------------------
1) Создайте хранилище и ключи по RuStore «Способ 2» или командами keytool
   (RSA не менее 2048 бит, validity 36500). Имя файла по умолчанию в проекте:
   android/solitaire-release.jks — либо своё имя и правка key.properties.
2) Алиасы: в скриптах PEPK сейчас --alias=solitaire; при другом имени ключа
   подписи приложения поправьте pepk_rustore.ps1 и upload alias в Gradle.
3) Скопируйте android/key.properties.example → key.properties, пропишите
   пароли и storeFile (файл key.properties в git не попадает).
4) Релизный AAB подписывайте ключом ЗАГРУЗКИ; в RuStore загрузите pepk_out.zip
   и upload_cert.pem — как в официальной инструкции.

Подготовка PEPK
---------------
- Java 11+.
- Скачать pepk.jar из окна «Загрузка подписи приложения» в RuStore Консоли.
- Положить pepk.jar в ТОТ ЖЕ каталог, из которого запускаете команду (так
  требует инструкция RuStore).

Готовый запуск (в репозитории)
-------------------------------
1) pepk.jar положен в android/signing_export/ (переименован с «pepk (1).jar»).
2) В консоли RuStore скопируйте encryptionkey из блока «Запустите инструмент».
3) Создайте файл android/signing_export/rustore_pepk.enckey — РОВНО ОДНА строка,
   без кавычек и пробелов по краям = этот ключ.
4) Запустите pepk_rustore.cmd (или: powershell -File pepk_rustore.ps1).
5) Пароли: интерактивно ИЛИ только в окружении (не в репозиторий и не в чат):
     set PEPK_STORE_PASS=...   & set PEPK_KEY_PASS=...   (если отличается от store)
   Затем тот же запуск скрипта.
6) Результат: pepk_out.zip рядом с скриптом — его загружайте в RuStore.

Ручная команда (альтернатива)
------------------------------
  java -jar pepk.jar ^
    --keystore="ПУТЬ\к\android\solitaire-release.jks" ^
    --alias=solitaire ^
    --output="ПУТЬ\к\signing_export\pepk_out.zip" ^
    --encryptionkey=КЛЮЧ_ИЗ_КОНСОЛИ ^
    --include-cert

После выполнения загрузите в RuStore:
  - получившийся pepk_out.zip
  - PEM сертификата ключа загрузки (см. ниже)

Сертификат ключа загрузки (PEM) для AAB
----------------------------------------
Тем алиасом и хранилищем, которыми подписан релизный AAB:

  keytool -exportcert -alias UPLOAD_ALIAS ^
    -keystore "ПУТЬ\к\solitaire-release.jks" -rfc -file upload_cert.pem

Подпись релиза в проекте задаётся в android/key.properties (не коммитить).
