# StreetKings Tablet External App Template

Este resource es una plantilla mínima para crear apps externas que aparecen dentro de la tablet de StreetKings.

## Uso

1. Copia esta carpeta fuera del resource `streetkings` y renómbrala, por ejemplo `sk_mechanic_app`.
2. En `fxmanifest.lua`, cambia `name`, rutas o metadatos si hace falta.
3. En `client.lua`, cambia `APP.id`, `APP.label`, `APP.icon`, `APP.color` y los callbacks NUI.
4. Asegúrate de iniciar el resource después de `streetkings`.

```cfg
ensure streetkings
ensure sk_mechanic_app
```

La UI debe incluir el SDK:

```html
<script src="https://cfx-nui-streetkings/html/js/tablet-sdk.js"></script>
```

Desde JavaScript usa:

```js
const result = await fetchNui('templateEcho', { text: 'hola' });
```

Ese evento llega al callback `RegisterNUICallback('templateEcho', ...)` del resource que registró la app.
