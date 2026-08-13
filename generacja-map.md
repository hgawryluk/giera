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
