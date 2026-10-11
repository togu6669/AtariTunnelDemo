# Checkpoint kontekstu

## Jezyk

- Rozmawiamy po polsku.

## Projekt

- Workspace: `F:\Prog\Atari\Demo`
- Interesujacy katalog: `F:\Prog\Atari\Demo\pascal`
- Glowny analizowany plik: `F:\Prog\Atari\Demo\pascal\src\main.pas`

## Technologia

- Kod jest napisany w Mad Pascalu dla Atari 8-bit.
- Program uzywa Display Listow ANTIC-a, bezposrednich zapisow do pamieci, procedur typu `Poke`, `DPoke`, `Move` oraz danych kompresowanych APLib.
- To wyglada jak demo/efekt wizualny, nie klasyczna gra.

## Wazne pliki

- `F:\Prog\Atari\Demo\pascal\src\main.pas`
- `F:\Prog\Atari\Demo\pascal\src\const_main.inc`
- `F:\Prog\Atari\Demo\pascal\src\const_data.inc`
- `F:\Prog\Atari\Demo\pascal\src\resources_main.rc`
- `F:\Prog\Atari\Demo\pascal\src\resources_data.rc`
- `F:\Prog\Atari\Demo\pascal\src\dlists\dlist_circles.asm`
- `F:\Prog\Atari\Demo\pascal\src\dlists\dlist_tunnel.asm`
- `F:\Prog\Atari\Demo\pascal\src\dlists\dlist_text.asm`
- `F:\Prog\Atari\Demo\pascal\src\dlists\dlist_zoomout.asm`

## Wazne adresy

- `MALE_ADDRESS = $4000`
- `FEMALE_ADDRESS = $6000`
- `CROSS_ADDRESS = $8000`
- `FONT_ADDRESS = $A000`
- `DL_CIRCLES_ADR = $ED00`
- `DL_TUNNEL_ADR = $EC80`
- `DL_ZOOMOUT_ADR = $EB00`
- `DL_TEXT_ADR = $EA80`
- `RMT_PLAYER = $F000`
- `RMT_MODUL = $F700`

## Zasoby

- `resources_data.rc` laduje dane:
  - `dasleben.apu`
  - `dertod.apu`
  - `dertunnel.apu`
  - `diegeburt.apu`
  - `man.apu`
  - `tunnel.apu`
  - `woman.apu`
- `resources_main.rc` laduje Display Listy z katalogu `dlists`.
- Dane `.apu` sa rozpakowywane przez `unAPL` / `xbunAPL`.

## Co robi main.pas

- Inicjalizuje Atari, ustawia `DMACTL`, kolory i wylacza system przez `SystemOff`.
- Przygotowuje strukture RMT, ale muzyka jest obecnie wylaczona przez `playMusic := 0`.
- Rozpakowuje `man.apu` do `MALE_ADDRESS` i `woman.apu` do `FEMALE_ADDRESS`.
- Wlacza DLI `dli_menu_circle` i ustawia Display Liste `DL_CIRCLES_ADR`.
- Animuje przejscie miedzy grafika mezczyzny i kobiety przez przepisywanie adresow LMS w Display Liscie.
- Robi efekt fill/fade, modyfikujac bajty grafiki bezposrednio w pamieci.
- Kopiuje aktualny obraz do `CROSS_ADDRESS` jako snapshot/stan posredni.
- Ma przygotowana procedure `showText` do wyswietlania plansz tekstowych, ale wywolania `showText` sa obecnie zakomentowane.
- Nastepnie przelacza sie na `DL_TUNNEL_ADR`, laduje `tunnel.apu` i ustawia wlasny charset pod `FONT_ADDRESS`.
- Efekt tunelu jest animowany przez zmiane definicji znakow w charsecie, glownie `setChar(i, 0)` i `setChar(j, 255)`.

## Podejrzenie / rzecz do sprawdzenia

- W `showText` mapowanie `text_tunnel` i `text_geburt` wyglada potencjalnie na zamienione:
  - `text_tunnel` laduje `ADR_DIEGEBURT`
  - `text_geburt` laduje `ADR_DERTUNNEL`
- Moze to byc celowe, ale wyglada podejrzanie.

## Stan

- Plik `main.pas` zostal odczytany i wstepnie zrozumiany.
- Odczytane zostaly tez stale, zasoby i Display Listy.
- Projekt nie byl jeszcze kompilowany ani uruchamiany.

## Zasady dalszej pracy

- Nie zakladac, ze to zwykly Pascal; uwzgledniac specyfike Mad Pascala i Atari 8-bit.
- Przed zmianami w efektach sprawdzac zalezne pliki `.inc`, `.rc` i odpowiednia Display Liste.
- Ostroznie z adresami pamieci, bo wiele efektow zalezy od recznego layoutu RAM.
