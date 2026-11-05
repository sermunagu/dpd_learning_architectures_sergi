# Revisión independiente de TAREA 01 y contraste con Fischer-Bühner et al. (2023)

**Fecha:** 4 de noviembre de 2026. **Alcance:** auditoría estática de `pnnn_root_cause_auditoria.zip`, recomputación independiente de resultados RF/imitación desde `experimentosSergi20261023(2).zip`, contraste matemático con *Phase-Normalized Neural Network for Linearization of RF Power Amplifiers* (IEEE Microwave and Wireless Technology Letters, 2023, DOI: 10.1109/LMWT.2023.3290980). No se ha ejecutado MATLAB ni se ha entrenado/rediseñado ningún modelo.

## 1. Dictamen

**TAREA 01 se considera coherente y suficiente como diagnóstico de lectura, sujeto a la distinción entre validación independiente y resultados de Codex que solo pudieron comprobarse internamente.** Los scripts `diagnose.m` y `verifyExtras.m` están restringidos a carga, predicción y cálculo de diagnósticos: no contienen llamadas de entrenamiento ni comandos RF. Escriben los resultados en directorios únicos bajo `diagnostics/pnnn_root_cause/`. Su reproducibilidad íntegra exige los checkpoints y experimentos MATLAB locales ignorados por Git. El ZIP remitido contiene tablas, informes y logs, **no la red densa ni el bundle P310 originales**.

## 2. Resultado experimental contrastado independientemente

Extrayendo las cinco estructuras `meas_out` del fichero RF MATLAB y el objetivo `y` de `_xy.mat` del ZIP original, se recalculó en Python la NMSE de imitación como `10*log10(sum(abs(x_pred-y_ILC)^2)/sum(abs(y_ILC)^2))`:

| Modelo | NMSE imitación (dB) | NMSE RF original (dB) |
|---|---:|---:|
| GMP-DOMP P310 | -38.413493999788 | -39.551645785215 |
| PN-IQ-GMP P310 | -38.872917515416 | -40.165922007678 |
| PNNN P310 | -35.126409532303 | -36.493678167268 |

La NMSE RF procede del campo `performance.NMSE` de la medición y no se confunde con la imitación. Las tres cifras de imitación coinciden con el informe de Codex al redondeo indicado. También se verificó que las señales PNNN medidas están almacenadas en precisión `single` y las de los dos modelos lineales en `double`.

## 3. Resultados de Codex: coherencia interna comprobada

El CSV de P310 de octubre contiene NMSE completa -38.875485 (PN-IQ), -35.572399 (PNNN densa) y -35.128892 (PNNN podada). Se han recalculado las diferencias de 3.303086 dB *antes* de poda y 0.443507 dB *adicionales* entre redes finales. No es una descomposición causal del entrenamiento.

Las tablas de capas dan 1008 pesos de entrada + 24 de salida + 14 sesgos en densa (1046); en P310, 273 pesos de entrada + 23 de salida + 14 sesgos (310). Once de las 84 entradas carecen de conexiones activas, incluida la 15; las doce neuronas conservan conexiones. `activations.csv` confirma un máximo por neurona de 1.8042% (densa) y 1.6610% (P310) bajo el umbral `h<.01 or h>.99`: no hay *saturación generalizada* con esa definición.

`loss_components.csv` es matemáticamente coherente con sigmaI = 0.0125525119001017 y sigmaQ = 0.00375762280052252; `(sigmaI/sigmaQ)^2 = 11.1592477280154`. En la pérdida de dos componentes normalizadas, el error físico Q recibe un peso por unidad de error cuadrático 11.159 veces el de I, en el sistema I/Q rotado respecto de la fase de entrada. Esto **no prueba** que la ponderación cause la brecha. PN-IQ mantiene menores errores físicos tanto radiales como de cuadratura en el diagnóstico.

`reference_metrics.csv` y `verification.log` informan un error relativo L2 de 8.105e-12 y una variación NMSE de 1.421e-12 dB en GMP, y coincidencia exacta de PN-IQ. La implementación de `verifyExtras.m` calcula correctamente estas magnitudes. **La reproducibilidad de esas comparaciones exactas no se pudo comprobar independientemente desde el ZIP**, porque no contenía el checkpoint lineal. La PNNN sí se reporta exacta respecto de su checkpoint en la sesión MATLAB anterior, también pendiente de verificación externa si se exige repetición independiente.

## 4. Contraste con el artículo original

En la sección II, ecuaciones (1)-(6), Fischer-Bühner et al. definen `r(k)=conj(x(k))/abs(x(k))`, rotan todos los taps respecto al *tap actual* y restauran la fase al final. El código `buildPhaseNormDataset.m` / `predictPNNN.m` implementa la misma idea. La convención `r=1` en entradas exactamente nulas es una decisión de implementación no definida por la fracción del artículo.

Los experimentos del artículo (sección III) emplean M=7, potencias de envolvente primera y tercera, una capa sigmoide y una salida lineal, 1000 épocas, 120.000 muestras de entrenamiento y un promedio de cinco inicializaciones para el estudio de modelado directo. La configuración se reutiliza en su experimento DPD. Su tabla I destaca un modelo de DPD de 959 parámetros reales y 29 neuronas, que, para una capa oculta y dos salidas, corresponde a **30 entradas**: `29*(30+3)+2=959`. El vector de entrada de 32 componentes (16 componentes I/Q de 8 taps + 16 envolventes de dos órdenes) elimina la Q instantánea cero y el módulo instantáneo redundante con la I instantánea, llegando a 30.

El baseline local **NO es una réplica idéntica**: M=13, órdenes [1,3,5,7], entrada `full` de 84, 12 neuronas, 1046 parámetros densos y poda por magnitud hasta P310. El artículo ajusta el número de neuronas para estudiar complejidad, y no describe el protocolo de poda global P310 de este repositorio. El PA, forma de onda, banda, condiciones RF y población de datos también difieren. La superioridad publicada de PN-RVTDNN no obliga a superar a PN-IQ-GMP con este baseline concreto.

**Detalle técnico a preservar:** `buildPhaseNormDataset(...,'pruned')` del repositorio elimina la Q del tap actual **y todas las envolventes del tap actual**; con cuatro órdenes elimina cinco canales (84→79), mientras que la exclusión explícita de cero + duplicado del artículo elimina únicamente dos (84→82 para M=13 y cuatro órdenes). El pipeline actual usa `featMode='full'`, así que esta divergencia **no explica el NMSE actual**; sí importa si se diseña una variante que se anuncie como fiel al esquema de entradas podadas del artículo.

El artículo no especifica que se deba aplicar necesariamente un z-score independiente a las dos salidas rotadas ni que esa pérdida normalizada sea obligatoria. Esa parte debe tratarse como una elección concreta del pipeline local, no como una exigencia de la formulación PN.

## 5. Limitaciones y siguientes decisiones

1. **Aceptable:** cerrar la TAREA 01 como auditoría exploratoria de solo lectura. Conservar el ZIP, sus logs y los manifiestos de hashes. No confundir registros de ejecución de Codex con una repetición MATLAB independiente.
2. **No probado:** que la red tenga capacidad insuficiente. Hay evidencia de limitaciones de representación/optimización, pero una red entrenada no define el óptimo de su clase funcional. Las 12 neuronas y el fuerte reparto de conexiones hacia la capa de salida justifican un diagnóstico posterior.
3. **Próximo experimento barato:** una única optimización P310 desde la **misma fuente densa inicial, máscara y configuración**, cambiando la pérdida para minimizar MSE física compleja (en las coordenadas rotadas). Mantener la comparación con el checkpoint exacto original, la selección de muestras, 164 épocas, RNG, Adam y la ruta no acelerada. Normalizar la nueva pérdida para no introducir una escala arbitraria, documentar que Adam no es exactamente invariante a escala y no ajustar hiperparámetros a posteriori.
4. **Alcance de ese experimento:** solo evalúa la pérdida durante el *fine-tuning* de una red densa previamente entrenada con la pérdida antigua; un resultado negativo **no descarta** el efecto de cambiar la pérdida en el entrenamiento denso.
5. **Posteriormente:** si se plantea reproducir más fielmente el estudio original, aislar por separado ancho de la red, número de taps/órdenes, tratamiento de dos características redundantes y semillas. No cambiar simultáneamente todos esos factores ni atribuir una diferencia a uno solo.
6. **Validación:** el complemento de identificación de octubre sigue siendo un conjunto de desarrollo; una nueva captura y posterior transmisión RF serían necesarias para reclamar generalización y mejoras de linealización física.

**No se han modificado archivos del repositorio del usuario ni se ha realizado ninguna medida o entrenamiento RF/MATLAB durante esta revisión.**
