# Acolytus

Un acólito discreto en la barra de menú de macOS (🔥). Hace los oficios menores
para que no estorben los mayores.

## Funciones

### Procesos de Node (`memorychip`)

Lista los procesos de `node` de tu usuario con su memoria, antigüedad y proyecto
(deducido de `…/<proyecto>/node_modules/…`), y marca los que sobran:

- **Huérfanos**: su padre murió y los adoptó `launchd` (PPID 1). El típico
  `next dev` o `vite` que sobrevivió a la terminal que lo lanzó.
- **Suspendidos**: los que dejaste con Ctrl+Z.

**Limpiar huérfanos** les manda `SIGTERM` y, si siguen vivos 1,5 s después,
`SIGKILL`; al terminar te dice cuánta memoria se liberó. También puedes marcar
a mano cualquier proceso y **Terminar selección**.

En **Proteger** puedes poner textos separados por comas (`tsserver, mi-daemon`)
para que esos procesos nunca se limpien automáticamente. Los zombis se muestran
pero no se pueden matar (ya no ocupan memoria; su padre debe recogerlos).

### Capturar frase (`quote.bubble`)

Guarda frases de internet (autor + contenido) en una carpeta de tu bóveda de
Obsidian, sin clasificarlas.

1. **Capturar pantalla** abre la selección de región (como ⌘⇧4). Seleccionas la
   publicación —Threads, X, Bluesky, Mastodon…— y el OCR de Vision (local, nada
   sale del Mac) extrae autor, usuario y texto, descartando hora, insignias,
   iconos y contadores.
2. **Del portapapeles** hace lo mismo con una imagen o un texto copiado (si
   copias desde Chrome, también toma la URL de origen).
3. Se abre una ventanita para revisar y corregir. **Guardar** (↩) escribe la nota.

La nota queda como `Autor — primeras palabras.md`:

```markdown
---
author: "Audrey London"
captured: 2026-10-02T10:15:00-05:00
---

> One German philosopher declared that God was a human projection, and an entire civilization shrugged and agreed.
>
> — Audrey London
```

La carpeta se elige la primera vez que guardas (o con **Cambiar…**); por
ejemplo `CH-Brain/Root/000_cris/Frases`.

## Instalación

Requiere macOS 13+ y Xcode (o las Command Line Tools con Swift 5.9+).

```bash
./scripts/build-app.sh --install   # compila, empaqueta y abre ~/Applications/Acolytus.app
```

- La primera captura pedirá permiso de **Grabación de pantalla**
  (Ajustes del Sistema → Privacidad y seguridad). Tras concederlo, reinicia Acolytus.
- Como la firma es ad-hoc, al recompilar macOS puede volver a pedir ese permiso.
- **Abrir al iniciar sesión** está en el pie del panel.

Para desarrollo: `swift run Acolytus` y `swift test` (los tests cubren el
parseo de `ps`, el parser de frases y el formato de la nota).

## Añadir una función

Cada función es un módulo independiente:

```
Sources/
├── AcolytusCore/            # Lógica pura y testeable (sin AppKit)
└── Acolytus/
    ├── Core/                # App, panel, protocolo AcolytusModule, Shell
    └── Modules/
        ├── NodeReaper/
        └── QuoteCapture/
```

1. Crea `Sources/Acolytus/Modules/MiFuncion/` con una clase que conforme a
   `AcolytusModule` (`id`, `title`, `symbol` y `makeView()`).
2. Añádela a `ModuleRegistry.modules` en `Core/AcolytusModule.swift`.
3. Si tiene lógica que valga la pena probar, ponla en `AcolytusCore` con sus tests.

Aparecerá como un icono más en la cabecera del panel.
