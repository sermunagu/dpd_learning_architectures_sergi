%% Configuración de la señal de identificación
% info_signal.mu = 1;         % Numerología. Valores posibles: entre 0 y 4
% No es necesario especificar todos los parámetros porque algunos están
% relacionados entre sí y se pueden deducir y otros tienen valor por
% defecto.
% Df = 2^info_signal.mu*15e3; % Separación entre subportadoras (Hz)
% info_signal.Df = Df;
% O bien
info_signal.Df = 60e3;
info_signal.M = 256;         % Número de símbolos de la constelación M-QAM  
% mapeada sobre todos los símbolos OFDM. Potencia de 2 y constelación cuadrada.
info_signal.NPRB = 38;      % Número de PRBs activos. Cada PRB contiene 12 
% subportadoras adyacentes. En la última versión del código, consideramos
% todos los PRBs están activos y agrupados en torno a la frecuencia central
% NFFT = 2^(nextpow2(info_signal.NPRB*12));
% info_signal.NFFT = NFFT;    % Tamaño de la FFT
info_signal.BW = 30e6;      % Ancho de banda de la canalizacion en Hz 
% No es el ocupado efectivo. Valores posibles
% [5e6 10e6 15e6 20e6 25e6 30e6 40e6 50e6 60e6 80e6 100e6]
info_signal.Nslots = 0.5;     % Numero de slots a contemplar. 
% Cada slot estandar contiene 14 simbolos OFDM. 
info_signal.ovs = 3;        % Factor de sobremuestreo, entero.
% fs = info_signal.NFFT*info_signal.Df;              % Frecuencia de muestreo sin sobremuestreo (Hz)
% info_signal.fs = fs;
% fsovs = info_signal.fs*info_signal.ovs;             % Frecuencia de muestreo con sobremuestreo (Hz)
% info_signal.fsovs = fsovs;
% info_signal.Foff = 0;       % Frecuencia de offset de cada banda en Hz. 
% Por defecto, 0
% info_signal.BWeff = info_signal.Df*info_signal.NPRB*12;
% Ancho de banda efectivo ocupado por la señal OFDM generada
info_signal.seed = 1000;    % Semilla del generador de números aleatorios 
% para crear la secuencia de símbolos. Por defecto, 1000
info_signal.centralSC = 0; % Bandera indicando si la subportadora central lleva información o no.
% Configuración del clipping
info_signal.fclipCarrier = 0;      % Bandera indicando si se desar hacer clipping o no, a cada banda por separado 
info_signal.fclip = info_signal.fclipCarrier;  
% Bandera indicando si se desar hacer clipping o no a la señal global. Con
% una sola banda, tiene que coincidir con lo que se haga en ella.
info_signal.PAPRdCarrier = 10.5; 
info_signal.PAPRd = info_signal.PAPRdCarrier; % PAPR deseada en caso de realizar cliping, PAPR <= PAPRd dB.
% Configuración del spectrum shaping
info_signal.SpectrumShaping = 'BPideal'; % 
info_signal.SpectrumShapingParam = 0; 
% Hay que darle algún valor, aunque se trate de un BPideal (sería un valor ficticio)
%info_signal.SpectrumShaping = 'RaisedCosine';
%info_signal.SpectrumShapingParam = 0.2; 

%% Configuración de otros parámetros
info_signal.ffig = 1; % Bandera indicando si deseamos mostras las figuras.



