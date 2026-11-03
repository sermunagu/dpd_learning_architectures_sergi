config_signal_2bandas
[x, xs, info_signal2] = genera_5GNR_multicarrier_v5(info_signal);
y=canalAWGN(x,60); 
[ACPR, ACPR2, EVM, NMSE] = analiza_medidas_5GNR_v5(x, y, info_signal2, 0)

config_signal
[x, xs, info_signal2] = genera_5GNR_multicarrier_v5(info_signal);

xr = resample(x,500e6,info_signal2.fsovs,200);
fsXn = 500e6;

y=canalAWGN(xr,60); 
y = resample(y,info_signal2.fsovs,500e6,200);

[ACPR, ACPR2, EVM, NMSE] = analiza_medidas_5GNR_v5(x, y, info_signal2, 0)