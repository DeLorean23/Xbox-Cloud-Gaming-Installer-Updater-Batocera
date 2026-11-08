# Xbox Cloud Gaming Installer & Updater für Batocera

*Created by DeLorean23* · [English: README.md](README.md)

Mit diesem Installer kommt **Xbox Cloud Gaming** als eigenes System in Batocera. Jedes Cloud-Spiel aus dem Game-Pass-Katalog wird ein normaler Eintrag in der Spieleliste, mit Name, Cover und Beschreibung. Du wählst ein Spiel aus und es startet **direkt im Stream** im Vollbild, ohne Menüs, alles mit dem Controller.

Als Programm dient der Open-Source-Streaming-Client **Greenlight** (https://github.com/unknownskl/greenlight). Der Installer lädt immer die neueste Greenlight-Version von GitHub.

## Download

**Xbox Cloud Gaming Installer & Updater.zip** gibt es unter **[Releases](https://github.com/DeLorean23/Xbox-Cloud-Gaming-Installer-Updater-Batocera/releases/latest)**.

## Voraussetzungen

- Batocera (x86_64-PC), Start als root (beim Start aus Ports automatisch)
- Internetverbindung
- Ein Microsoft-Konto mit **Xbox Game Pass Ultimate** (Cloud Gaming gehört zu Ultimate)
- **Einmal** eine Tastatur zum Anmelden, danach reicht der Controller

## Installation

1. Den Inhalt der ZIP nach `/userdata` entpacken, damit landen der Installer und das Cover in `/userdata/roms/ports/`.
2. In Batocera die Spieleliste aktualisieren und unter **Ports** den Eintrag **Xbox Cloud Gaming Installer & Updater** starten.
3. Den Warnhinweis lesen und mit **y** bzw. **A** am Controller bestätigen.
4. Der Installer lädt die neueste Greenlight-Version, richtet das System ein und baut die Spieleliste. Fortschrittsbalken zeigen, was gerade passiert:
   - Step 1/3: Liste aller Cloud-Spiele
   - Step 2/3: Namen und Details (deutscher Store)
   - Step 3/3: Cover
5. Dann kommt „Sign in now?“. Mit **y / A** öffnet sich Xbox Cloud Gaming in einem Fenster. Mit deinem Microsoft-Konto anmelden (Tastatur). Sobald die Startseite zu sehen ist, das Fenster mit **Hotkey + Start** oder **Alt + F4** schließen.
6. Am Ende fragt er „Reboot now?“. Mit **y / A** startet Batocera neu. Danach ist das neue System **Xbox Cloud Gaming** in der Systemauswahl.

Die Anmeldung kannst du auch überspringen und später machen: **F1 → Anwendungen → Xbox Cloud Gaming**.

## So funktioniert es

- Die Spieleliste kommt aus dem **öffentlichen Xbox-Game-Pass-Katalog** (`catalog.gamepass.com`), Markt Deutschland, deutsche Namen. Für die Liste ist keine Anmeldung nötig.
- Es kommen nur Spiele rein, die du mit dem Game Pass spielen kannst. Titel, die nur spielbar sind, wenn du sie besitzt, bleiben draußen.
- Für jedes Spiel legt der Installer eine kleine Datei `/userdata/roms/xboxcloud/<Name>.xcloud` an. Darin steht nur die xCloud-Titel-ID des Spiels.
- Die Cover liegen in `/userdata/roms/xboxcloud/images/`, Namen, Beschreibungen, Publisher und Genre in der `gamelist.xml`.
- Startest du ein Spiel, ruft Batocera `/userdata/system/xboxcloud/launch.sh` auf. Das Skript liest die Titel-ID und startet Greenlight im Vollbild mit `--connect=xcloud_<ID>`, so geht der Stream sofort los.
- **Hotkey + Start** (Select + Start oder Guide + Start) beendet den Stream und bringt dich zurück zur Spieleliste.

## Was installiert wird

- Greenlight in `/userdata/system/xboxcloud/XboxCloudGaming.AppImage` (Hilfsskripte und Logo im selben Ordner)
- System **Xbox Cloud Gaming** (`xboxcloud`): `/userdata/system/configs/emulationstation/es_systems_xboxcloud.cfg`
- Spieleordner: `/userdata/roms/xboxcloud/`
- **F1 → Anwendungen → Xbox Cloud Gaming**: öffnet das Programm ohne Spiel, zum Anmelden und für Einstellungen
- Systemlogo für jedes Theme, das es übernehmen kann (Themes in schreibgeschützten Ordnern werden übersprungen und am Ende aufgelistet)
- Cover für den Ports-Eintrag

## Update

Den Installer einfach erneut unter **Ports** starten:

- Gibt es eine neuere Greenlight-Version, wird sie nach einer y/n-Frage installiert. Die vorherige Version bleibt in `/userdata/system/xboxcloud/backup`.
- Die Spieleliste wird **jedes Mal neu gebaut**, so kommen neue Game-Pass-Cloud-Spiele dazu und entfernte verschwinden. Vorhandene Cover werden nicht noch einmal geladen.
- Ist das Programm schon aktuell, steht „up to date“.
- Nach einem Update ist kein Neustart nötig.

## Hinweise

- Das ist ein inoffizielles System. Ein späteres Batocera-Update kann es beeinflussen.
- Greenlight ist ein inoffizieller Client und nicht von Microsoft. Microsoft kann Cloud Gaming jederzeit ändern.
- Die Spieleliste nutzt deutsche Namen und den deutschen Store. Ein paar Spiele behalten eventuell ihren englischen Namen.
- Dieses Projekt stellt keine Spiele oder Konten bereit. Du brauchst ein eigenes Game-Pass-Ultimate-Abo.
- Xbox und Game Pass sind Marken von Microsoft. Dieses Projekt hat nichts mit Microsoft zu tun.
- Log-Dateien bei Problemen: `/userdata/system/logs/xboxcloud-installer.log` und `/userdata/system/logs/xboxcloud.log`

## Bauen

`./build.sh` erstellt die ZIP in `dist/` aus `src/installer.template.sh`, den Hilfsskripten in `src/` und den Bildern in `assets/`.

## Lizenz

Der Installer steht unter der [MIT-Lizenz](LICENSE). Greenlight ist ein eigenes Projekt mit eigener Lizenz; dieser Installer lädt es nur aus den offiziellen Releases herunter.
