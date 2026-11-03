%% EJEMPLO DPD - Ejecutar las secciones por separado

%% 1. ILC: obtener medidas del PA (requiere ADRV conectado)
main_1_learnDPD

%% 2. DPD: entrenar y exportar 
filenamedate = '20261023T102742';  % Descomentar si no vienes directamente de main_1

dpd_mode = 'sweep';              % 'single' o 'sweep'
dpd_single_P = 310;              % Solo en modo single
dpd_parameter_grid = 20:10:500;  % Solo en modo sweep
dpd_export_mode = 'combined';    % 'combined' o 'per_budget'

clear dpd_sweep_directory dpd_rf_parameters       % Barrido nuevo
% dpd_sweep_directory = 'RUTA_AL_SWEEP_GUARDADO'; % Reutilizar checkpoints
main_2_sergiDPD

%% 3. RF: seleccionar y medir (requiere la sesion de main_1 y TRx conectado)
% dpd_comparison_type = 'sergi_sweep'; % Para single: 'sergi_p310'
% dpd_indices = 89;                    % PN-IQ P310 (grid 20:10:500)
% dpd_indices = 88:90;                 % Los tres modelos de P310
clear dpd_indices                      % Transmitir todos los modelos
clear dpd_n_regressors
main_3_testDPD