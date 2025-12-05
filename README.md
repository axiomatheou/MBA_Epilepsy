# MBA_Epilepsy

Modelo basado en agentes de epilepsia como transición de fase hacia estados de hipersincronía neuronal, implementado en NetLogo mediante osciladores caóticos acoplados tipo Kuramoto con restricción energética.

Proyecto final del curso de Modelación Basada en Agentes, Facultad de Ciencias, UNAM.

Autor: Santiago Caballero Rosas  

## Ejecución del modelo

Requisitos:
- NetLogo 6.4.0 o versión compatible.

Pasos:
1. Abrir NetLogo.
2. Cargar Fuentes (codigo)/Epilepsia_V6_5_final.nlogo
3. Ejecutar setup.
4. Ejecutar go.

Los parámetros (µ, κ, radio, α, β, γ, número de neuronas y topología) pueden ajustarse desde la interfaz.

---

## Experimentos

Se realizaron barridos sistemáticos de parámetros con BehaviorSpace (~1750 simulaciones):

- Experimento 1: transición de sincronización sin restricción energética.
- Experimento 2: mapa de probabilidad de crisis en el espacio (κ, µ).
- Experimento 3: relación entre energía y duración de crisis.
- Experimento 4: comparación con y sin variable lenta de energía.

Los resultados están disponibles en la carpeta Experimentos/.

---

## Alcance del modelo

Modelo fenomenológico orientado a reproducir cualitativamente:
- Transiciones de fase de sincronización.
- Emergencia de crisis epilépticas.
- Autolimitación ictal por agotamiento energético.

No es un modelo biofísico ni clínico.

---

## Contacto

Santiago Caballero Rosas  
axiomatheou@ciencias.unam.mx  
Facultad de Ciencias, UNAM

axiomatheou@ciencias.unam.mx  
Facultad de Ciencias, UNAM
****
