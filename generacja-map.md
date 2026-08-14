# Generacja map — zasady osadzania terenu i obiektów

## Granice mapy

- Każdy system ograniczający ruch musi pobierać rozmiar z aktywnej mapy przez `GridManager.get_exploration_world_size()`.
- Nie wolno zakładać na stałe starego rozmiaru `160 × 190`, jeśli mapa ma inne wymiary.
- Po zmianie rozmiaru należy przetestować przejście przez dawne granice X=159 oraz Z=189.

## Kamienie, drzewa i inne obiekty naziemne

- Pozycję Y wyliczamy z `GridManager.terrain_height(x, z)`.
- Lokalną normalną terenu wyliczamy z co najmniej czterech próbek wysokości wokół punktu.
- Kamienie dopasowujemy osią Y do normalnej zbocza i dopiero potem dodajemy losowy obrót wokół tej normalnej.
- Obiekty naturalne wolno częściowo zagłębiać. Typowy zakres:
  - małe kamienie: 8–16% ich wysokości,
  - duże głazy: 12–25%, szczególnie na stromych stokach,
  - drzewa: bryła korzeniowa 5–12% wysokości pnia; pień musi pozostać pionowy, chyba że projekt wymaga przechylenia.
- Zagłębienie powinno rosnąć wraz z nachyleniem, aby dolna krawędź obiektu nie wisiała nad opadającym gruntem.
- Polany, ścieżki i miejsca startowe pozostawiamy wolne od dużych przeszkód.
- Przed zaakceptowaniem generacji sprawdzamy obiekt z kilku stron oraz z widoku FPP.

## Kolizje

- Dekoracyjne drobne skały nie powinny tworzyć przypadkowych niewidzialnych blokad.
- Kolizje stosujemy tylko dla dużych, czytelnych przeszkód i dopasowujemy je do widocznej bryły.
- Należy odróżnić ścianę wynikającą z kolizji od programowego clampowania pozycji gracza.

## Multi-dekoracje i wydajność

- Powtarzalne dekoracje (drzewa, kamienie, krzewy, trawa i drobny clutter) rozmieszczamy przez `MultiMeshInstance3D`, osobny batch dla każdego unikalnego mesha lub materiału.
- Nie tworzymy dziesiątek ani setek osobnych `MeshInstance3D`, jeżeli obiekty nie wymagają indywidualnych skryptów, animacji lub unikalnej kolizji.
- Transform każdej instancji powinien zawierać losowy obrót, kontrolowaną wariację skali i wysokość pobraną z terenu.
- Drzewa pozostają zasadniczo pionowe; dopuszczalne jest jedynie subtelne przechylenie. Kamienie mogą podążać za normalną zbocza.
- Duże landmarki mogą używać znacznie większej skali, lecz powinny być nieliczne i umieszczone świadomie.
- Przy losowaniu zachowujemy minimalny odstęp między drzewami oraz wykluczamy rzeki, wąwozy, polany startowe i bardzo strome zbocza.

## Materiały terenu i paczki PBR

- Preferujemy kompletne zestawy PBR: `Color`, `NormalGL`, `Roughness` i `Displacement/Height`; map `NormalDX` nie używamy w Godot bez odwrócenia kanału Y.
- Warstwy malowane muszą zachowywać ciągłe, wygładzone wagi. Po height blendzie i noise zawsze normalizujemy sumę wag przed mieszaniem albedo, normal oraz roughness.
- Height blending służy do naturalnego wchodzenia materiału o wyższym reliefie w sąsiednią warstwę; nie może zamieniać miękkiej maski pędzla w próg 0/1.
- Na stromych zboczach stosujemy triplanar mapping z regulowaną ostrością, aby ograniczyć rozciąganie tekstur oglądanych pod kątem.
- Noise granic ma być subtelny i działać na kilku metrach świata. Nie może tworzyć regularnego pasa wzdłuż rzeki ani ujawniać granic kafla.
- Parametry `blend_softness`, `height_blend_strength`, `noise_strength`, `noise_scale` i `triplanar_sharpness` pozostawiamy w materiale jako łatwo edytowalne uniformy Inspectora.
- Importowane paczki tekstur przechowujemy logicznie pod `res://assets/textures/terrain/`; nie kopiujemy do projektu plików Blender, USD, miniaturek ani duplikatów, jeśli runtime ich nie używa.
- Zmiana materiałów nie może naruszać map kontrolnych Terrain3D, geometrii heightmapy ani kolizji; malowanie tekstur musi pozostać kompatybilne z istniejącymi ID warstw.
