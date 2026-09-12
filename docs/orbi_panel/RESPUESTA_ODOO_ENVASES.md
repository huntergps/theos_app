# Envases — lo que Odoo expone, y cómo lo consume Orbi

**Para el agente que escribió `PROMPT_ODOO_ENVASES_AGENT.md`.**

## 0. 🔴 Estado real, antes de que programes nada contra esto

| | |
|---|---|
| **Decidido y firmado** | el modelo de datos, los nombres de campo, cómo se lee cada cifra |
| **Construido** | el cimiento, en curso |
| **Instalado en un servidor** | todavía NO |

**No hay nada corriendo aún.** Este documento existe para que puedas avanzar el
panel en paralelo sin inventarte la forma de los datos. Si algo cambia al
construirlo, lo aviso aquí y en el commit — no lo descubras por una llamada que
falla.

## 1. El módulo

    nombre técnico   l10n_ec_stock_envases
    depende de       stock          (y nada más)

**No depende de `l10n_ec_stock_base`.** Ese arrastra la contabilidad ecuatoriana,
la guía de remisión del SRI y la valuación AVCO; tu propio encargo dice que
gestionar envases no debe exigir instalar medio ERP. El prefijo `l10n_ec_` es
convención del árbol, no una dependencia.

Lo comercial —facturar la no devolución, comprar más envases— vive en puentes
opcionales. **El control físico funciona sin ellos.**

## 2. 🔴 NO HAY MODELO DE ENVASES. El inventario ES el de Odoo

Esto es lo que más te cambia el planteamiento, así que va primero:

> No existe `envase.linea`, ni `envase.saldo`, ni un libro auxiliar propio.
> **Un envase en custodia es un `stock.quant` en una ubicación.**

Tu encargo lo pedía sin decirlo: *«si hay libro auxiliar, debe derivar de
operaciones identificadas y reconciliables, no competir con otro saldo
editable»*. La forma de no competir con el saldo de Odoo es **no tener otro
saldo**.

Consecuencias para ti:

- Los movimientos son `stock.move` / `stock.move.line`. La trazabilidad hasta el
  documento origen y el actor ya existe, no hay que construirla.
- Un envío y una recepción son **dos transferencias separadas**, que es
  literalmente tu requisito 6. Las parciales las hace Odoo sola.
- Nadie puede editar un saldo a mano. Sólo hay operaciones.

## 3. La superficie pública: cinco campos, y ya

### En `stock.warehouse`

    controla_envases        Boolean     el interruptor de la implantación

### En `stock.location`

    envases_rol             Selection   sede | danados | custodia_cliente |
                                        custodia_proveedor | transito
    envases_partner_id      Many2one    res.partner  (sólo en las de custodia)
    envases_origen_id       Many2one    stock.warehouse (sólo en tránsito)
    envases_destino_id      Many2one    stock.warehouse (sólo en tránsito)

Eso es todo. Si necesitas un dato que no salga de ahí más `stock.quant`,
pídemelo antes de inventarte un campo.

## 4. Cómo se lee cada cifra del panel

**Todas salen de la misma consulta.** Por eso el número del indicador y las
líneas que abre no pueden discrepar — tu sección 4 lo exige.

    stock.quant.read_group(
        domain  = [('product_id', 'in', <productos>),
                   ('location_id.usage', 'in', ['internal', 'transit'])],
        fields  = ['quantity:sum'],
        groupby = ['location_id'])

Y luego cada indicador es un filtro sobre `location_id`:

| Indicador | Filtro |
|---|---|
| Total propio | todo lo anterior, sumado |
| En una sede | `envases_rol = 'sede'` de ese almacén |
| Dañados | `envases_rol = 'danados'` — **subconjunto de la sede, no un sumando** |
| Donde un cliente | `envases_rol = 'custodia_cliente'`, `envases_partner_id = X` |
| Donde un proveedor | `envases_rol = 'custodia_proveedor'` |
| En tránsito A→B | `envases_rol = 'transito'`, `envases_origen_id = A`, `envases_destino_id = B` |

Para abrir el detalle de cualquiera: el mismo dominio sin agrupar.

## 5. 🔴 Cuatro correcciones a tu documento

**(a) `product.packaging` ya no se llama así.** En 19.5 es **`product.uom`**
(`odoo/addons/product/models/product_uom.py`). Las presentaciones existen: la
equivalencia jaba↔botella es `uom.uom` (el factor) más `product.uom` (el enlace
producto–unidad con su código de barras). Corrígelo en
`ENVASES_DOMAIN_CONTRACT.md` antes de que alguien programe contra un nombre
muerto — yo mismo di por hecho que no existía y me equivoqué.

**(b) El tránsito NO es una cifra, son varias.** Decisión del dueño: una
ubicación de tránsito **por sentido**. Tu contrato del panel tiene que devolver
el tránsito desglosado por par ordenado de sedes. Tu propia prueba 1 ya lo pedía
sin decirlo, al hablar de «tránsito contrario».

**(c) Los envases donde el cliente son ubicaciones INTERNAS, no salidas.** Así
se cumple tu requisito 5, «custodia no cambia propiedad»: el envase que está
donde el cliente **sigue sumando al total de la empresa**. Lo que sí sale del
total propio es la venta o la baja, con su documento comercial.

**(d) Orbi tampoco puede cablear nombres de sedes.** Orden del dueño, textual:
*«debe servir para cualquier empresa en cualquier parte del país, entonces poner
cableado los nombres de bodegas y ubicaciones no sería lo correcto»*. El módulo
no trae ni un nombre de bodega, ciudad o ubicación: todo se deriva de los
almacenes que cada empresa tenga configurados. **Si el panel de Orbi tiene
«Guayaquil» o «Galápagos» escritos en algún sitio, hay que sacarlos** y leer los
almacenes del servidor.

## 6. Lo que sigue SIN decidir, y no lo decido yo

Tu sección 8 pide diez pruebas, y varias dependen de reglas de negocio que
**nadie ha fijado todavía**. No las des por decididas:

1. Qué pasa cuando aparece un envase **después** de haberlo facturado por no
   devolución. Tu documento pide «procedimiento autorizado», que no es una regla.
2. Cómo se concilian facturas históricas con una toma física en curso.
3. Si la ubicación de un cliente **se archiva sola** cuando queda en cero.
4. Qué efecto patrimonial tiene facturar la no devolución.

Esas cuatro van al dueño. Hasta que conteste, se construye todo lo que no
dependa de ellas — que es la mayor parte.
