;;============================================================================
;; MODELO DE EPILEPSIA - RED NEURONAL
;; v6.5 - ya funciona bien despues de mil correcciones
;; Santiago Caballero Rosas
;;============================================================================

globals [
  order-parameter-r        ;; el parametro de Kuramoto, lo importante
  order-parameter-psi
  mean-energy
  mean-state
  synchronization-level
  seizure-detected?
  seizure-counter
  ticks-above-threshold
  in-seizure?
  a-param b-param c-param d-param  ;; constantes del oscilador de Miramontes

  ;; para medir duracion de crisis
  current-seizure-start
  seizure-durations
  mean-seizure-duration
  last-seizure-duration
]

turtles-own [
  x-state y-state    ;; variables del oscilador 2D
  s-local            ;; estado "observable"
  s-coupled
  energy             ;; energia metabolica, la variable lenta
  phase-angle        ;; fase para calcular r
  neuron-type        ;; excitatoria o inhibitoria
  my-neighbors
  neighbor-count
  mu-local           ;; excitabilidad con un poco de variacion
]

;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  ;; cargar la imagen de fondo si existe
  carefully [
    import-drawing "brain_background.png"
  ] [
    ;; si no esta la imagen no pasa nada
  ]

  ;; constantes de Miramontes (no tocar)
  set a-param 0.5
  set b-param 1.0
  set c-param 1.0
  set d-param 0.5

  set seizure-counter 0
  set seizure-detected? false
  set ticks-above-threshold 0
  set in-seizure? false

  set current-seizure-start 0
  set seizure-durations []
  set mean-seizure-duration 0
  set last-seizure-duration 0

  create-turtles num-neurons [
    setup-neuron
  ]

  ;; topologia de red
  if network-topology = "grid" [ setup-grid-topology ]
  if network-topology = "random" [ setup-random-topology ]
  if network-topology = "small-world" [ setup-small-world-topology ]

  update-statistics

  ;; prints de diagnostico (!!)
  print "=== SETUP COMPLETO ==="
  print (word "N = " count turtles)
  print (word "Topologia = " network-topology)
  print (word "mu promedio = " precision (mean [mu-local] of turtles) 3)
  print (word "Vecinos promedio = " precision (mean [neighbor-count] of turtles) 1)
  print (word "r inicial = " precision order-parameter-r 4)

  reset-ticks
end

to setup-neuron
  setxy random-xcor random-ycor

  ;; condiciones iniciales aleatorias en [-4, 4]
  ;; esto es importante para que r empiece bajo
  set x-state random-float 8.0 - 4.0
  set y-state random-float 8.0 - 4.0

  set s-local tanh-custom (x-state - y-state)
  set s-coupled s-local

  set energy E0-baseline
  set mu-local mu-excitability * (0.8 + random-float 0.4)  ;; un poco de heterogeneidad

  ;; 80% excitatorias tipicamente
  ifelse random-float 1.0 < excitatory-ratio [
    set neuron-type "excitatory"
    set shape "circle"
  ] [
    set neuron-type "inhibitory"
    set shape "square"
  ]

  set phase-angle compute-phase x-state y-state
  update-neuron-color
  set size 1.5
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; TOPOLOGIAS ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to setup-grid-topology
  let grid-size ceiling sqrt num-neurons
  let spacing (world-width - 2) / grid-size

  let i 0
  ask turtles [
    let row floor (i / grid-size)
    let col i mod grid-size
    setxy (min-pxcor + 1 + col * spacing) (max-pycor - 1 - row * spacing)
    set i i + 1
  ]

  ask turtles [
    set my-neighbors other turtles in-radius (spacing * 1.5)
    set neighbor-count count my-neighbors
  ]
end

to setup-random-topology
  ask turtles [
    set my-neighbors other turtles in-radius connection-radius
    set neighbor-count count my-neighbors
  ]
end

to setup-small-world-topology
  ;; primero ponemos todos en circulo
  let n count turtles
  let angle-step 360 / n
  let radius-sw (world-width / 2) - 2

  let i 0
  ask turtles [
    let angle i * angle-step
    setxy (radius-sw * sin angle) (radius-sw * cos angle)
    set i i + 1
  ]

  ask turtles [
    set my-neighbors other turtles in-radius (connection-radius * 0.5)
    set neighbor-count count my-neighbors
  ]

  ;; rewiring del 10% para hacer small-world
  ask turtles [
    if random-float 1.0 < 0.1 [
      let random-neighbor one-of other turtles
      if random-neighbor != nobody [
        set my-neighbors (turtle-set my-neighbors random-neighbor)
        set neighbor-count count my-neighbors
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; GO ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to go
  if not any? turtles [ stop ]

  ;; el orden importa aqui (!)
  ask turtles [ update-oscillator ]
  ask turtles [ set s-local tanh-custom (x-state - y-state) ]
  ask turtles [ apply-coupling ]
  ask turtles [ update-energy ]

  if fluid-network? [ update-dynamic-neighborhoods ]

  ask turtles [
    set phase-angle compute-phase x-state y-state
    update-neuron-color
  ]

  update-statistics
  detect-seizure

  ;; print cada 100 ticks para no saturar
  if ticks mod 100 = 0 and ticks > 0 [
    print (word "t=" ticks ": r=" precision order-parameter-r 4
           ", E=" precision mean-energy 1
           ", crisis=" seizure-counter
           ", dur_prom=" precision mean-seizure-duration 1)
  ]

  tick
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; OSCILADOR ;;;
;;;;;;;;;;;;;;;;;;;;;;;

;; aqui esta la dinamica principal del modelo
;; ecuaciones de Miramontes + acoplamiento tipo Kuramoto
to update-oscillator
  ;; energia modula la excitabilidad
  let energy-factor energy / E0-baseline
  if energy-factor < 0 [ set energy-factor 0 ]
  if energy-factor > 1 [ set energy-factor 1 ]

  ;; mu efectivo baja si no hay energia
  let mu-min 0.5
  let mu-eff mu-local * energy-factor
  if mu-eff < mu-min [ set mu-eff mu-min ]

  ;; campo sinaptico de los vecinos
  let field 0
  if any? my-neighbors and kappa-coupling > 0 [
    let coupling-factor energy / E0-baseline
    if coupling-factor < 0 [ set coupling-factor 0 ]
    if coupling-factor > 1 [ set coupling-factor 1 ]

    let local-field compute-coupling-field
    set field kappa-coupling * coupling-factor * local-field
  ]

  ;; ruido para que no se quede pegado
  let noise-amp 0.1
  let noise-x noise-amp * (random-float 2.0 - 1.0)
  let noise-y noise-amp * (random-float 2.0 - 1.0)

  ;; las ecuaciones del oscilador (Miramontes, 1993)
  let x-new tanh-custom (mu-eff * (a-param * x-state - b-param * y-state) + field) + noise-x
  let y-new tanh-custom (mu-eff * (c-param * x-state + d-param * y-state) + field) + noise-y

  set x-state x-new
  set y-state y-new
end

;; OJO: esto fue el bug principal
;; netlogo NO modifica variables let dentro de ask
;; hay que usar sum [...] of
to-report compute-coupling-field
  let n-count count my-neighbors
  if n-count = 0 [ report 0 ]

  let total sum [
    (ifelse-value (neuron-type = "excitatory")
      [ J-excitatory ]
      [ J-inhibitory ])
    * s-local
  ] of my-neighbors

  report total / n-count
end

to apply-coupling
  set s-coupled s-local
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; ENERGIA ;;;
;;;;;;;;;;;;;;;;;;;;;;;

;; la variable lenta que hace que las crisis terminen
to update-energy
  let activity abs s-coupled
  let cost-activity alpha-cost * activity

  ;; costo extra por estar sincronizado con vecinos
  let cost-sync 0
  if any? my-neighbors and gamma-sync-cost > 0 [
    let my-s s-coupled
    let neighbor-states [s-coupled] of my-neighbors
    let similarity 1 - (mean (map [ns -> abs (ns - my-s)] neighbor-states) / 2)
    set cost-sync gamma-sync-cost * similarity
  ]

  ;; recuperacion hacia el baseline
  let recovery beta-recovery * (E0-baseline - energy)
  set energy energy - cost-activity - cost-sync + recovery

  ;; límites
  if energy < 0 [ set energy 0 ]
  if energy > E0-baseline [ set energy E0-baseline ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; RED FLUIDA ;;;
;;;;;;;;;;;;;;;;;;;;;;;

;; esto es opcional, hace que la conectividad cambie dinamicamente
to update-dynamic-neighborhoods
  ask turtles [
    let local-sync-level 0

    if any? my-neighbors [
      let my-s s-coupled
      let similarity-sum sum [abs (s-coupled - my-s)] of my-neighbors
      set local-sync-level 1 - (similarity-sum / count my-neighbors / 2)
    ]

    let dynamic-radius connection-radius * (0.8 + 0.4 * local-sync-level)
    set my-neighbors other turtles in-radius dynamic-radius
    set neighbor-count count my-neighbors
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; VISUALIZACION ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to update-neuron-color
  ;; brillo segun el estado
  let brightness (s-coupled + 1) / 2

  let energy-factor energy / E0-baseline
  if energy-factor < 0.5 [
    set brightness brightness * (0.5 + energy-factor)
  ]

  ;; amarillo-naranja
  let r-comp floor (255 * brightness)
  let g-comp floor (200 * brightness)
  let b-comp floor (50 * brightness)

  set color rgb r-comp g-comp b-comp
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; ESTADISTICAS ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to update-statistics
  set mean-energy mean [energy] of turtles
  set mean-state mean [s-coupled] of turtles
  calculate-order-parameter
  set synchronization-level order-parameter-r
end

;; el parametro de orden de Kuramoto
;; r = |<e^(i*theta)>|
to calculate-order-parameter
  let N count turtles
  if N = 0 [
    set order-parameter-r 0
    set order-parameter-psi 0
    stop
  ]

  let sum-cos sum [cos phase-angle] of turtles
  let sum-sin sum [sin phase-angle] of turtles

  let mean-cos sum-cos / N
  let mean-sin sum-sin / N

  set order-parameter-r sqrt (mean-cos * mean-cos + mean-sin * mean-sin)
  set order-parameter-psi atan mean-sin mean-cos
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; DETECTOR DE CRISIS ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to detect-seizure
  let threshold-r 0.6    ;; si r pasa de esto, es crisis
  let min-duration 10    ;; tiene que durar al menos esto

  ifelse order-parameter-r > threshold-r [
    set ticks-above-threshold ticks-above-threshold + 1

    if (not in-seizure?) and (ticks-above-threshold >= min-duration) [
      set in-seizure? true
      set seizure-counter seizure-counter + 1
      set seizure-detected? true
      set current-seizure-start ticks
      print (word ">>> CRISIS #" seizure-counter " INICIADA en t=" ticks " (r=" precision order-parameter-r 3 ")")
    ]
  ] [
    if ticks-above-threshold > 0 [
      set ticks-above-threshold ticks-above-threshold - 1
    ]

    if in-seizure? and (ticks-above-threshold = 0) [
      set in-seizure? false
      set seizure-detected? false

      let duration ticks - current-seizure-start
      set last-seizure-duration duration
      set seizure-durations lput duration seizure-durations
      set mean-seizure-duration mean seizure-durations

      print (word "<<< CRISIS TERMINADA en t=" ticks
             " | Duracion: " duration " ticks"
             " | Duracion promedio: " precision mean-seizure-duration 1 " ticks")
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; AUXILIARES ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to-report tanh-custom [x]
  ;; para evitar overflow
  if x > 20 [ report 1 ]
  if x < -20 [ report -1 ]
  let e-pos exp x
  let e-neg exp (- x)
  report (e-pos - e-neg) / (e-pos + e-neg)
end

to-report compute-phase [x y]
  ifelse (abs x < 0.001) and (abs y < 0.001) [
    report random-float 360  ;; si está en el origen, fase aleatoria
  ] [
    let angle atan y x
    if angle < 0 [ set angle angle + 360 ]
    report angle
  ]
end

;; botones para jugar con los parametros en tiempo real
to increase-excitability
  set mu-excitability mu-excitability + 0.1
  if mu-excitability > 3 [ set mu-excitability 3 ]
end

to decrease-excitability
  set mu-excitability mu-excitability - 0.1
  if mu-excitability < 0.5 [ set mu-excitability 0.5 ]
end

to increase-coupling
  set kappa-coupling kappa-coupling + 0.1
  if kappa-coupling > 1 [ set kappa-coupling 1 ]
end

to decrease-coupling
  set kappa-coupling kappa-coupling - 0.1
  if kappa-coupling < 0 [ set kappa-coupling 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
230
10
762
543
-1
-1
12.2
1
10
1
1
1
0
0
0
1
-21
21
-21
21
1
1
1
ticks
30.0

BUTTON
10
10
115
43
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
125
10
220
43
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
55
220
88
num-neurons
num-neurons
10
500
200.0
10
1
NIL
HORIZONTAL

SLIDER
10
95
220
128
mu-excitability
mu-excitability
0.5
3.0
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
10
135
220
168
kappa-coupling
kappa-coupling
0.0
1.0
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
10
175
220
208
E0-baseline
E0-baseline
50
200
100.0
10
1
NIL
HORIZONTAL

SLIDER
10
215
220
248
alpha-cost
alpha-cost
0.0
2.0
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
10
255
220
288
beta-recovery
beta-recovery
0.0
0.2
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
10
295
220
328
gamma-sync-cost
gamma-sync-cost
0.0
1.0
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
10
335
220
368
J-excitatory
J-excitatory
0.5
2.0
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
10
375
220
408
J-inhibitory
J-inhibitory
-1.0
0.0
-0.5
0.1
1
NIL
HORIZONTAL

SLIDER
10
415
220
448
excitatory-ratio
excitatory-ratio
0.5
0.95
0.8
0.05
1
NIL
HORIZONTAL

CHOOSER
10
455
220
500
network-topology
network-topology
"grid" "random" "small-world"
1

SLIDER
10
505
220
538
connection-radius
connection-radius
1
20
10.0
1
1
NIL
HORIZONTAL

SWITCH
10
545
220
578
fluid-network?
fluid-network?
1
1
-1000

PLOT
770
10
1030
180
Parametro de Orden (r)
Tiempo
r
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"r" 1.0 0 -2674135 true "" "plot order-parameter-r"
"umbral" 1.0 0 -7500403 true "" "plot 0.6"

PLOT
770
190
1030
360
Energia Promedio
Tiempo
E
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"energia" 1.0 0 -10899396 true "" "plot mean-energy"

PLOT
770
370
1030
540
Estado Promedio
Tiempo
s
0.0
100.0
-0.5
0.5
true
false
"" ""
PENS
"estado" 1.0 0 -13345367 true "" "plot mean-state"

MONITOR
1040
10
1165
55
r
order-parameter-r
4
1
11

MONITOR
1040
65
1165
110
Energia
mean-energy
1
1
11

MONITOR
1040
120
1165
165
Estado
mean-state
3
1
11

MONITOR
1040
175
1165
220
Crisis?
seizure-detected?
0
1
11

MONITOR
1040
230
1165
275
N Crisis
seizure-counter
0
1
11

MONITOR
1040
285
1165
330
Dur. Ultima
last-seizure-duration
0
1
11

MONITOR
1040
340
1165
385
Dur. Promedio
mean-seizure-duration
1
1
11

BUTTON
10
590
115
623
+mu
increase-excitability
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
125
590
220
623
-mu
decrease-excitability
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
635
115
668
+kappa
increase-coupling
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
125
635
220
668
-kappa
decrease-coupling
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## EPILEPSIA EN EL BORDE DEL CAOS
### Modelo de crisis epilépticas como transición de fase

**Autor:** Santiago Caballero Rosas  
**Institución:** Facultad de Ciencias, UNAM
**Curso:** Modelación Basada en Agentes  
**Versión:** 6.5 (Diciembre 2025)

---

### ¿Qué es?

Este modelo simula cómo emergen las crisis epilépticas a partir de la sincronización excesiva de redes neuronales. Cada agente representa una población neuronal que oscila caóticamente; cuando el acoplamiento entre neuronas supera un umbral crítico, el sistema transita abruptamente de actividad normal (desincronizada) a hipersincronía patológica (crisis).

### ¿Cómo funciona?

El modelo combina tres componentes:

1. **Osciladores caóticos** (Miramontes, 1993): Cada neurona tiene dinámica interna no lineal controlada por el parámetro μ (excitabilidad).

2. **Acoplamiento tipo Kuramoto** (1975): Las neuronas se influencian mutuamente según su conectividad. El parámetro κ controla la fuerza de acoplamiento.

3. **Variable lenta energética**: La sincronía consume energía metabólica. Cuando la energía se agota, la crisis termina automáticamente.

### ¿Para qué sirve?

Demuestra que la epilepsia puede entenderse como una **transición de fase**: el mismo tipo de cambio abrupto que ocurre cuando el agua se congela, pero aquí lo que "se congela" es la dinámica neuronal en un estado patológico.

El modelo reproduce:
- Transición abrupta a crisis
- Auto-terminación por agotamiento energético
- Periodo postictal (recuperación)
- Dependencia de la topología de red

### Parámetros clave

- **κ (kappa-coupling):** Fuerza de acoplamiento sináptico. Mayor κ → más sincronía.
- **μ (mu-excitability):** Excitabilidad neuronal. Hay una ventana óptima (~1.75-2.0) para crisis.
- **Parámetros de energía (α, β, γ):** Controlan el consumo y recuperación metabólica.

### Indicador principal

- **r (parámetro de orden):** Mide sincronización global (0 = caos, 1 = sincronía total). Crisis cuando r > 0.6.

---

**Basado en:** Kuramoto (1975), Miramontes et al. (1993), Jirsa et al. (2014)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

square
false
0
Rectangle -7500403 true true 30 30 270 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Exp1_Sincronizacion_Pura" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>order-parameter-r</metric>
    <metric>mean-energy</metric>
    <metric>seizure-counter</metric>
    <metric>mean-seizure-duration</metric>
    <metric>last-seizure-duration</metric>
    <enumeratedValueSet variable="num-neurons">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mu-excitability">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="E0-baseline">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excitatory-ratio">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-excitatory">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-inhibitory">
      <value value="-0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fluid-network?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha-cost">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta-recovery">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma-sync-cost">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="connection-radius" first="3" step="2" last="15"/>
    <steppedValueSet variable="kappa-coupling" first="0" step="0.1" last="1"/>
  </experiment>
  <experiment name="Exp2_Kappa_Mu" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>order-parameter-r</metric>
    <metric>mean-energy</metric>
    <metric>seizure-counter</metric>
    <metric>mean-seizure-duration</metric>
    <metric>last-seizure-duration</metric>
    <enumeratedValueSet variable="num-neurons">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="E0-baseline">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excitatory-ratio">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-excitatory">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-inhibitory">
      <value value="-0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fluid-network?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha-cost">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta-recovery">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma-sync-cost">
      <value value="0.4"/>
    </enumeratedValueSet>
    <steppedValueSet variable="kappa-coupling" first="0" step="0.1" last="1"/>
    <steppedValueSet variable="mu-excitability" first="1.5" step="0.25" last="2.5"/>
  </experiment>
  <experiment name="Exp3_Energia" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>order-parameter-r</metric>
    <metric>mean-energy</metric>
    <metric>seizure-counter</metric>
    <metric>mean-seizure-duration</metric>
    <metric>last-seizure-duration</metric>
    <enumeratedValueSet variable="num-neurons">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mu-excitability">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="E0-baseline">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excitatory-ratio">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-excitatory">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-inhibitory">
      <value value="-0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fluid-network?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-radius">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kappa-coupling">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="gamma-sync-cost" first="0" step="0.1" last="0.8"/>
    <steppedValueSet variable="beta-recovery" first="0.01" step="0.02" last="0.1"/>
  </experiment>
  <experiment name="Exp4_Comparacion_ConSin_Energia" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>order-parameter-r</metric>
    <metric>mean-energy</metric>
    <metric>seizure-counter</metric>
    <metric>mean-seizure-duration</metric>
    <metric>last-seizure-duration</metric>
    <enumeratedValueSet variable="num-neurons">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mu-excitability">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="E0-baseline">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="excitatory-ratio">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-excitatory">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="J-inhibitory">
      <value value="-0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fluid-network?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-radius">
      <value value="12"/>
    </enumeratedValueSet>
    <steppedValueSet variable="kappa-coupling" first="0.4" step="0.1" last="0.9"/>
    <enumeratedValueSet variable="alpha-cost">
      <value value="0"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta-recovery">
      <value value="0"/>
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma-sync-cost">
      <value value="0"/>
      <value value="0.4"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
