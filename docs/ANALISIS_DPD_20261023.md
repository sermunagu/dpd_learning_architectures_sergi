# Análisis de los experimentos DPD — 23/10/2026

Captura `experiment20261023T102742`, 100 MHz de ancho de banda; 491 520 muestras, `fs = 491.52 MHz`. Fuentes: `experiment..._report.pdf`, `experiment..._DPD_custom.mat`, `experiment..._DPD_offline_comparison.mat`, ficheros de seguridad CSV y `experiment..._xy.mat`.

## Resultados RF

| Caso | NMSE RF (dB) | ACPR izquierdo (dB) | ACPR derecho (dB) | EVM (%) | Pout (dBm) |
|---|---:|---:|---:|---:|---:|
| ILC iter. 1 (referencia inicial) | -16.2987 | -25.4805 | -24.9302 | 14.5128 | 42.1571 |
| ILC iter. 15 | -50.3492 | -56.7161 | -57.5967 | 3.2257 | 41.4953 |
| GMP-LS del tutor | -38.8242 | -47.3875 | -47.7375 | 3.3907 | 41.4985 |
| GMP-DOMP, P310 | -39.5516 | -47.5509 | -48.0657 | 3.3070 | 41.3609 |
| PN-IQ-GMP, P310 | **-40.1659** | **-47.8352** | **-48.6196** | **3.2909** | 41.3574 |
| PNNN, P310 | -36.4937 | -43.4324 | -44.8867 | 3.4496 | 41.3580 |

PN-IQ-GMP mejora a GMP-DOMP en 0.6143 dB NMSE RF; mejora ACPR en 0.2843 dB y 0.5539 dB. La potencia de salida entre los tres modelos P310 es prácticamente idéntica (≈41.36 dBm), un control favorable para la comparación de esa adquisición.

## Imitación offline, verificación directa

Se han extraído las señales complejas `meas_out(k).x` (antes de CFR) de cada registro DPD y se ha calculado `10 log10( sum(abs(x_model-x_ILC).^2) / sum(abs(x_ILC).^2) )`, utilizando como `x_ILC` la columna `y` del `_xy.mat` de la misma captura.

| Caso | NMSE de imitación (dB) |
|---|---:|
| GMP-LS tutor | -36.7320 |
| GMP-DOMP, P310 | -38.4135 |
| PN-IQ-GMP, P310 | **-38.8729** |
| PNNN, P310 | -35.1264 |

El ranking reproduce los resultados RF. Pero el NMSE de imitación no es directamente comparable numéricamente al NMSE RF. El último procede de la función `ACPROFDM` del tutor, que normaliza las formas de onda medidas (`y/norm(y)` y `u/norm(u)`) antes de obtener el error en dB.

## Seguridad

Los tres modelos P310 pasan `check_dpd_signal_safety` (`safe=1`). GMP-DOMP tiene PAPR antes de CFR de 15.0071 dB y se recorta levemente a 15 dB; PN-IQ-GMP tiene 14.8094 dB, PNNN 13.8798 dB y ninguno de estos dos precisa CFR.

## Límites y próximos experimentos

Los modelos P310 se midieron una vez cada uno, en una misma sesión y con potencias de salida cercanas. Falta repetir la comparación para estimar variabilidad e incertidumbre. El ILC iter. 15 es el objetivo de imitación y un referente RF superior, no una prueba independiente. GMP-LS del tutor es otra arquitectura y no consta aquí igualdad de parámetros con P310: evitar comparaciones atribuidas únicamente al algoritmo. Las mejoras de ACPR son modestas y requieren más capturas si se quieren formular conclusiones robustas. El informe PDF adjunto presenta la convergencia ILC, no por sí solo las métricas de los tres modelos: estas vienen de `DPD_offline_comparison.mat`.
