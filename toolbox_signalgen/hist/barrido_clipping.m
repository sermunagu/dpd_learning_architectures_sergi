%% Sweep de PAPR objetivo con clipping
clear; clc;

%% Cargar configuración
config_signal_100MHz_ADRV

fc = 0;

%% Generar señal base
[x, xs, info_signal] = genera_5GNR_multicarrier_v5(info_signal);

%% Rango de PAPR objetivo
PAPR_range = 8:0.25:10;

NMSE = zeros(size(PAPR_range));
EVM  = zeros(size(PAPR_range));
ACPR = zeros(size(PAPR_range));

%% Activar clipping
info_signal.fclip = 1;

for k = 1:length(PAPR_range)

    info_signal.PAPRd = PAPR_range(k);

    %% Aplicar clipping
    x_clip = clipping_PAPR_ICF(x, PAPR_range(k), info_signal.BWeff/info_signal.fsovs, 5);

    %% Medidas
    [ACPRk, ACPR2, EVM(k), NMSE(k)] = analiza_medidas_5GNR_v5(x, x_clip, info_signal, fc);
    ACPR(k) = ACPRk(1);
    close all;
end

%% Graficas
figure

subplot(3,1,1)
plot(PAPR_range, NMSE,'-o','LineWidth',1.5)
grid on
xlabel('Target PAPR (dB)')
ylabel('NMSE (dB)')
title('NMSE vs Target PAPR')

subplot(3,1,2)
plot(PAPR_range, EVM,'-o','LineWidth',1.5)
grid on
xlabel('Target PAPR (dB)')
ylabel('EVM (%)')
title('EVM vs Target PAPR')

subplot(3,1,3)
plot(PAPR_range, ACPR,'-o','LineWidth',1.5)
grid on
xlabel('Target PAPR (dB)')
ylabel('ACPR (dB)')
title('ACPR vs Target PAPR')