# Bindings locales Odoo: branding, login, colores y fuentes

Alcance: inspección estática de `/Users/elmers/Documents/dev_odoo20`.
Código presente no equivale a módulo instalado ni a configuración validada en
una base. No se consultó BD/ERP2 ni se llamó una instancia.

## Fuente verificada: `base_gpstech`

Manifest localizado en `addons/base_gpstech/__manifest__.py:4-61`, versión
declarada `19.5.6.3.0`, dependencias `web`, `mail`, `base_setup`, `auto_install`
y assets frontend/backend. No se comprobó estado instalado.

Campos que extienden `res.company` están en
`addons/base_gpstech/models/res_company.py:10-49`:

| Campo | Fuente/uso | Fallback verificable |
|---|---|---|
| `gpst_login_logo` | Binary adjunto por compañía | `/base_gpstech/static/src/img/logo_theos_hd.png` |
| `gpst_login_background` | Binary adjunto por compañía | `login_bg.jpg` |
| `gpst_login_favicon` | Binary adjunto por compañía | `/web/static/img/favicon.ico` |
| `gpst_login_title` | Char por compañía | `Theos` |
| `gpst_login_background_preset` | Selection generado leyendo `static/src/img/fondos` | fallback anterior |
| `gpst_login_favicon_preset` | Selection generado leyendo `static/src/img/favicons` | fallback anterior |

La resolución de fondo y fallback está en
`models/res_company.py:154-204`: upload de compañía > preset incluido > imagen
default; pareja `_claro`/`_oscuro` se resuelve sólo si el archivo oscuro existe,
con validación de ruta. El selector y la edición están en Ajustes, no en una
API, mediante relacionados `res.config.settings` en
`models/res_config_settings.py:5-28` y vista
`views/res_config_settings_views.xml:4-58`. El `setting` tiene
`company_dependent="1"` (`:10-12`), por tanto la configuración es por empresa.

El login hereda `web.login_layout` con prioridad 30 y usa
`request.env.company.sudo()` antes de autenticación en
`views/login_templates.xml:18-64`; favicon/título para todo `web.layout` están en
`:82-99`. No hay controlador custom de login ni endpoint de branding en este
módulo. El acceso pre-auth depende de la compañía que Odoo resuelva para la
request; no se debe inferir selección por usuario sin probarla en la instalación.

Colores y fuentes no son campos de compañía en este binding: `login.scss:19-23`
fija `$gpst-blue #0dafc8`, y `:56-67` aplica Poppins. Las fuentes auto-hospedadas
están en `static/src/fonts` y declaradas en `poppins.css:1-53` (también pesos
500/600/700 en `:55-135`). El modo oscuro del login usa
`prefers-color-scheme` (`login.scss:163-184`); no usa la cookie del backend.
El hook fuerza `res.company.email_secondary_color` globalmente a `#0dafc8` en
`hooks.py:7-11`; esto requiere `mail` y no es un selector de color por usuario.

## Binding consumible por Orbi (presente, pero no endpoint HTTP)

`l10n_ec_collection_box_pos/models/collection_config.py` implementa métodos
públicos de modelo:

- `res.company.pos_app_branding(known_checksums=None)` en `:212-223`, exige
  `check_access('read')` y que la compañía esté en `env.companies`; devuelve
  versión 1, tema, login, URLs y SHA-256, sin bytes adjuntos.
- `_pos_app_branding_for_company` en `:122-209` sanea colores allow-listados,
  tamaños y rutas; lee colores desde `ir.config_parameter` en `:69-87` y detecta
  si `base_gpstech` está instalado en `:103-107`. Fallbacks y assets están en
  `:144-208`; `known_checksums` puede producir `unchanged=true`.
- `collection.config.pos_app_capabilities()` en `:60-67` exige lectura y
  devuelve versión/config/company/counter policies.

La prueba estática de forma/seguridad existe en
`tests/test_pos_app_capabilities.py:42-128`: rechaza colores inseguros y
presets `..`, prueba fallback sin `base_gpstech`, compañía fuera de permitidas,
usuario interno, ACL de capabilities y checksum. Son tests en código; no fueron
ejecutados aquí, por lo que instalación/permisos efectivos siguen sin comprobar.

## Rutas y caché verificables

`controllers/web_auth.py:29-57` expone `/orbi`, `/orbi/` y assets con
`auth='user'`; `/orbi/bootstrap` es `auth='user'`, `readonly`, y devuelve
identidad/empresa/compañías/capabilities en `:59-96`. Bootstrap envía
`Cache-Control: no-store` y `X-Orbi-Session-Scope`; no incluye branding.
Assets `canvaskit/` e `icons/` son inmutables (`:51-57,108-133`). No existe en
los controladores inspeccionados una ruta HTTP que invoque
`pos_app_branding`; no inventar `/orbi/branding`. El integrador debe usar el
transporte público realmente disponible y documentarlo/probarlo.

## Implicaciones para integración

- Orbi puede consumir `pos_app_branding` como fuente remota, con prioridad por
  propiedad **personalización Orbi → Odoo → predeterminado Orbi**. Debe confirmar
  cómo se invoca el método desde la instalación real. Véase
  [Personalización](PERSONALIZATION_SPEC.md).
- La configuración visual `tema_*` es global vía `ir.config_parameter`, mientras
  login/logo/fondo/favicon/título son por compañía; no mezclarlas ni tratarlas
  como preferencias por usuario.
- No hay campo/fuente configurable de familia tipográfica: el binding verificado
  entrega `base_font_size`, no un nombre de fuente; Poppins es asset fijo del
  módulo. Cualquier ampliación requiere backend explícito.
- Instalación, ACL, compañía efectiva pre-auth, versión de assets y cache headers
  de `/web/image` quedan pendientes de validar en una base de prueba.

Referencias fuente principales: `base_gpstech/__manifest__.py`,
`base_gpstech/models/res_company.py`, `base_gpstech/views/login_templates.xml`,
`l10n_ec_collection_box_pos/models/collection_config.py` y
`l10n_ec_collection_box_pos/controllers/web_auth.py`.
