# Lunchappen för iPhone

Ett Xcode-projekt som paketerar Lunchappen som en riktig iOS-app. Appen fungerar helt offline och sparar all data i telefonen. Med appen följer:

- **Apple Kartor** som hittar restaurangen du är på. Den kräver ingen extern tjänst.
- **Delningsmenyn** för export av CSV och säkerhetskopior, till exempel till Filer, Mail eller AirDrop.
- **Haptisk återkoppling** när du sparar ett utlägg, och en varning när veckobudgeten överskrids.
- **Statusraden** som följer det utseende du valt i appen.

Krav: en Mac med Xcode 15 eller senare och ett Apple Developer-konto för att ladda upp till App Store.

## Köra appen

1. Öppna `ios/Lunchappen.xcodeproj` i Xcode.
2. Välj målet **Lunchappen**, fliken **Signing & Capabilities**, och välj ditt team under **Team**.
3. Ändra **Bundle Identifier** (`com.nicman101.lunchappen`) om du vill ha ett annat. Det måste vara unikt.
4. Välj en simulator eller din iPhone och tryck på ▶︎.

## Ladda upp till App Store Connect

1. Skapa appen på [App Store Connect](https://appstoreconnect.apple.com) under **Appar**, **+** och **Ny app**. Använd samma Bundle ID som i Xcode.
2. Välj **Any iOS Device (arm64)** som mål i Xcode.
3. Välj **Product** och sedan **Archive**.
4. I fönstret Organizer väljer du arkivet och **Distribute App**, sedan **App Store Connect** och **Upload**.
5. Bygget dyker upp i App Store Connect efter en stund. Där kan du testa med TestFlight eller skicka in för granskning.

Höj **Build** (`CURRENT_PROJECT_VERSION`) inför varje ny uppladdning, och **Version** (`MARKETING_VERSION`) inför varje ny release.

## Uppgifter till App Store Connect

- **Kategori:** Ekonomi.
- **Integritet (App Privacy):** "Data samlas inte in". Utläggen och positionen sparas bara i telefonen. Positionen skickas bara till Apple Kartor för att söka restauranger.
- **Skärmbilder:** krävs för 6,9-tumsskärm (till exempel iPhone 16 Pro Max-simulatorn). Ta dem med ⌘S i simulatorn.
- **Integritetspolicy (URL):** https://nicman101.github.io/Lunchappen/privacy.html

## Uppdatera appens innehåll

Appen byggs från `src/app.html`. Kör `node src/build.js` från repots rot. Skriptet uppdaterar både webbversionen och `ios/Lunchappen/Web`, och skapar ikonerna på nytt.
