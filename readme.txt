# MBA_Epilepsy

Modelo basado en agentes de epilepsia como transición de fase hacia estados de hipersincronía neuronal, implementado en NetLogo mediante osciladores caóticos acoplados tipo Kuramoto con restricción energética.

Proyecto final del curso de Modelación Basada en Agentes, Facultad de Ciencias, UNAM.

Autor: Santiago Caballero Rosas  
Profesores: Dr. Gustavo Carreón Vázquez, M. en C. Marco Antonio Jiménez Limas  
Semestre: 2026-1

---

## Estructura del repositorio

Caballero_Rosas/  
└── MBA_Epilepsy/  
  ├── Fuentes (codigo)/  
  │ ├── Epilepsia_V6_5_final.nlogo  
  │ ├── Brain_background.png  
  │ └── Experimentos/  
  │  ├── raw/  
  │  ├── graphics/  
  │  ├── Exp1_*.csv  
  │  ├── Exp2_*.csv  
  │  └── Exp3_*.csv  
  ├── MBA_ProyectoFinal.pdf  
  └── README.md  

---

## Contenido

Fuentes (codigo)/ contiene el código principal del modelo, los recursos gráficos utilizados por NetLogo y la carpeta de resultados experimentales.

Epilepsia_V6_5_final.nlogo es el archivo principal del modelo. Implementa:
- Osciladores caóticos tipo Miramontes–Solé–Goodwin.
- Acoplamiento sináptico tipo Kuramoto.
- Variable lenta de energía metabólica.
- Detección automática de crisis mediante el parámetro de orden global.

Brain_background.png es la imagen de fondo cargada en el mundo de NetLogo.

Experimentos/ contiene los datos generados por BehaviorSpace:
- raw/: resultados crudos sin procesar.
- graphics/: gráficas utilizadas en el reporte.
- Exp1_*.csv: transición de sincronización sin energía.
- Exp2_*.csv: mapa de epileptogenicidad (κ, µ).
- Exp3_*.csv: efecto de la variable lenta de energía.

MBA_ProyectoFinal.pdf contiene el desarrollo completo del proyecto: marco teórico, formulación matemática, arquitectura del modelo, resultados, discusión y conclusiones.

---

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
