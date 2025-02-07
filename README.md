# Autobuild First Device

## Beschreibung
Damit alles Automatisiert erstellt wird im SmartHome, soll ein Raspberry Pi als erstes Gerät dienen, welches über einen USB Stick automatisch eingerichtet wird.

## USB-Stick
Der USB-Stick soll Bootfähig sein und ein fertiges Raspberry Pi OS enthalten. Beim Starten des Pis soll das System vom USB-Stick starten und über ein Skript die SD-Karte formatieren. Anschließend setzte es ein neues Raspberry Pi OS auf und setzt die Konfigurationen um. Zu den Konfigurationen gehören:
- Updaten des Systems
- local-admin Account anlegen
- root anmeldung sperren
- Netzwerkeinstellungen tätigen
- Docker installieren
- Ansible in Docker zur Verfügung stellen mit NGINX Proxy

## Hardware
Als Hardware wird ein vorhandener Raspberry Pi genutzt. Dieser wird so eingerichtet, dass er von einem USB-Stick booten kann. Er wird über LAN verbunden sein.
Zum Einrichten des USB-Boots sind folgende Schritte erforderlich:
1. Raspberry Pi OS auf eine SD-Karte installieren
2. in der *config.txt* Datei unter *boot* folgende Zeile am Ende einfügen: ```program_usb_boot_mode=1```
3. nun die SD-Karte in den Pi stecken und booten
4. nach erfolgreichem boot kann der USB-Stick eingesteckt werden und die SD-Karte entfernt werden
(Der Pi versucht immer zuerst von der SD-Karte zu starten. Wenn diese formatiert oder entfernt ist, wird das booten über USB-Stick durchgeführt)

## Software
Auf dem USB-Stick ist als Betriebssystem Raspberry Pi OS. In diesem Image wurde die Sprache, das Tastaturlayout, der Service und der Benutzer admin bereits festgelegt.
Als Betriebssystem auf der SD-Karte dient Raspberry Pi OS, welche nach installation upgedatet wird. Das Image hierfür ist auf dem USB-Stick als [os.img](os.img) gespeichert. In diesem Image wurde die Sprache, das Tastaturlayout und der Benutzer admin bereits festgelegt.
Auf dem Pi soll Ansible in einem Dockercontainer laufen.

## SD-Karten-Image erstellung
Zum erstellen des vorkonfiguriertem Images muss ein frisches Image auf die SD-Karte installiert werden und das benötigte anschließend konfiguriert werden:
- Sprache und Tastaturlayout auf deutsch stellen
- Als Nutzer wird *admin* mit dem festgelegten Passwort gewählt. 
- [setup.service](setup.service) wird unter */etc/systemd/system* abgelegt
- abschließend wird im laufenden Betrieb ```systemctl enable setup.service``` ausgeführt, damit der Service bei jedem Start ausgeführt wird

Anschließend wird die Karte mit Win32 Disk Imager als eigenes Image gelesen. Dazu muss unter Image-Datei ein Pfad angegeben mit dem Namen der Datei. Diese darf noch nicht vorhanden sein, da sie sonst überschrieben wird. Ein Pfad könnte sein: *C:\Users\Christian\Downloads\os.img* Als Datenträger muss die Karte gewählt sein. Anschließend wird mit Lesen das Image gespeichert.

## USB-Stick-Image erstellung per Hand
Zum erstellen des vorkonfiguriertem Images muss ein frisches Image auf die SD-Karte installiert werden und das benötigte anschließend konfiguriert werden:
- Sprache und Tastaturlayout auf deutsch stellen
- Als Nutzer wird *admin* mit dem gleichnamigen Passwort gewählt. 
- [first_start.service](first_start.service) wird unter */etc/systemd/system* abgelegt
- [first_start.sh](first_start.sh) wird unter */usr/local/sbin* abgelegt
- [setup.sh](setup.sh) wird unter */usr/bin* abgelegt
- [setup.service](setup.service) wird unter */etc/systemd/system* abgelegt
- [Image](os.img) wird unter */usr/local/sbin* abgelegt
- abschließend wird im laufenden Betrieb ```systemctl enable first_start.service``` ausgeführt, damit der Service bei jedem Start ausgeführt wird

Anschließend wird die Karte mit Win32 Disk Imager als eigenes Image gelesen. Dazu muss unter Image-Datei ein Pfad angegeben mit dem Namen der Datei. Diese darf noch nicht vorhanden sein, da sie sonst überschrieben wird. Ein Pfad könnte sein: *C:\Users\Christian\Downloads\First-Device.img* Als Datenträger muss die Karte gewählt sein. Anschließend wird mit Lesen das Image gespeichert.

## USB-Stick-Image erstellen per Github
Zum erstellen des vorkonfiguriertem Images wird Github Action verwendet mit decrytion. Dort wird ein frisches Image heruntergeladen, wo das benötigte anschließend konfiguriert werden:
- Sprache und Tastaturlayout auf deutsch stellen
- Als Nutzer wird *admin* mit dem gleichnamigen Passwort gewählt. 
- [first_start.service](first_start.service) wird unter */etc/systemd/system* abgelegt
- [first_start.sh](first_start.sh) wird unter */usr/local/sbin* abgelegt
- [setup.sh](setup.sh) wird unter */usr/bin* abgelegt
- [setup.service](setup.service) wird unter */etc/systemd/system* abgelegt
- [Image](os.img) wird unter */usr/local/sbin* abgelegt
- abschließend wird im laufenden Betrieb ```systemctl enable first_start.service``` ausgeführt, damit der Service bei jedem Start ausgeführt wird

Zum Schluss wird das erstellte Image in die Nextcloud hochgeladen, von wo es heruntergeladen werden kann und auf einen USB Stick gespielt werden kann.
