function [x, xs, info] = genera_5GNR_multicarrier_v5(info)

% Generacion de señal multicarrier
% [x, xs, info] = genera_5GNR_multicarrier_v5(info)
%     info: Estructura con los parámetros de configuración de la señal.
%           Los más importantes son:
%           info.mu: Numerología. La separación entre subortadoras en Hz
%                es Df = 2^mu*15e3. Valores posibles: entre 0 y 4
%           info.M: Número de símbolos de la constelación M-QAM mapeada
%                sobre todos los símbolos OFDM. Potencia de 2 y constelación
%                cuadrada.
%           info.NPRB: Número de PRBs activos. Cada PRB contiene 12
%                subportadoras adyacentes.
%           info.BW: Ancho de banda de la canalizacion en Hz (no el ocupado
%                efectivo). Valores posibles [5e6 10e6 15e6 20e6 25e6 ...
%                30e6 40e6 50e6 60e6 80e6 100e6]
%           info.Nslots: Numero de slots a contemplar. Cada slot estandar contiene 14
%                simbolos.
%           info. ovs: Factor de sobremuestreo, entero.
%           info. Foff: Frecuencia de offset de la banda en Hz.
%           info.seed: Semilla del generador de números aleatorios para crear la secuencia de símbolos.
%           info.fclip: Bandera indicando si deseamos hacer clippling o no.
%           info.PAPRd: En caso de que info.fclip = 1, PAPR <= PAPRd dB.
%           info.SpectrumShaping: Tipo de filtro para hacer Spectrum
%                Shaping. Opciones: 'BPideal' o 'RaisedCosine'
%

x = [];

Ncarriers = length(info.NPRB);

if ~isfield(info, 'Df'),
    % Separación entre subportadoras (Hz)
    info.Df = 2.^info.mu*15e3;
else
    info.mu = log2(info.Df/15e3);
end
if ~isfield(info, 'NFFT'),
    info.NFFT = 2.^(nextpow2(info.NPRB.*12));
end
if ~isfield(info, 'fs'),
    info.fs = info.NFFT.*info.Df;
end
if ~isfield(info, 'ovs'),
    info.ovs = info.fsovs./info.fs;
else
    info.fsovs = info.ovs.*info.fs;
end
if ~isfield(info, 'Foff'),
    info.Foff = 0;
end
if ~isfield(info, 'BWeff'),
    info.BWeff = info.Df.*info.NPRB.*12;
end
if ~isfield(info, 'seed'),
    info.seed = 999+[1:Ncarriers];
end
if ~isfield(info, 'ffig'),
    info.ffig = zeros(1,Ncarriers);
end
if ~isfield(info, 'centralSC'),
    info.centralSC = zeros(1,Ncarriers);
end

for isignal = 1:Ncarriers,

    Df = info.Df(isignal);
    mu = info.mu(isignal);
    M = info.M(isignal);
    NPRB = info.NPRB(isignal);
    Nslots = info.Nslots(isignal);
    BW = info.BW(isignal);
    NFFT = info.NFFT(isignal);
    fs = info.fs(isignal);
    fsovs = info.fsovs(isignal);
    ovs = info.ovs(isignal);
    Foff = info.Foff(isignal);
    BWeff = info.BWeff(isignal);
    seed = info.seed(isignal);
    centralSC = info.centralSC(isignal);

    ffig = info.ffig(isignal);
    clip.flag = info.fclipCarrier(isignal);
    clip.PAPRd = info.PAPRdCarrier(isignal);

    if Ncarriers == 1,
        tipoSS.filtro = info.SpectrumShaping;
    else
        tipoSS.filtro = info.SpectrumShaping{isignal};
    end
    tipoSS.param = info.SpectrumShapingParam(isignal);

    xs(:,isignal) = OFDM(NPRB,mu,M,BW,NFFT,fsovs,seed,Nslots,centralSC,ffig,tipoSS,clip);

    % Desplazamiento a Foff
    N = length(xs(:,isignal));
    if isempty(x),
        x = xs(:,isignal).*exp(1i*2*pi*(0:N-1).'/fsovs * Foff);
    else
        x = x + xs(:,isignal).*exp(1i*2*pi*(0:N-1).'/fsovs * Foff);
    end

end

if ~centralSC,
    x = x - mean(x);
end
x  = x  / max(abs(x));

if info.fclip,

    PAPRx = 20*log10(max(abs(x))/rms(x));
    disp(sprintf('PAPR antes de clipping global: %4.2f dB\n', PAPRx));

    clip_th = 10^((info.PAPRd-PAPRx)/20);
    disp(sprintf('Muestras a las que se le aplica clipping global: %d (%4.8f %% de %d)\n', sum(abs(x)>clip_th), sum(abs(x)>clip_th)/length(x),length(x)));
    x( abs(x)>clip_th) = clip_th*exp(1i*angle( x(abs(x)>clip_th)));

    PAPRx = 20*log10(max(abs(x))/rms(x));
    disp(sprintf('PAPR despues de clipping global: %4.2f dB\n', PAPRx));

end

if ffig & (length(x)>8e3),
    fespectro = figure;
    espectro(x, fsovs, fespectro);
end

end


function x = OFDM(NPRB,mu,M,BW,NFFT,fsovs,seed,Nslots,centralSC,ffig,tipoSS,clip)

%% Inicializacion de variables
rng(seed); % Inicialización del generador de datos aleatorios
Df = 2^mu * 15e3;  % Separación entre subportadoras (Hz)
k=log2(M);             % Numero de bits por simbolo
M1 = sqrt(M);
M2 = sqrt(M);
k1 = log2(M1);
k2 = log2(M2);
Nsymb_OFDM = 14*Nslots; % Numero de simbolos OFDM
Nsc = NPRB*12;        % Numero de subportadoras activas
BWeff = Nsc*Df;       % Ancho de banda efectivo ocupado
Nb = Nsymb_OFDM*Nsc*k;
fs = NFFT*Df; % Tasa de muestreo del símbolo OFDM (Hz)
% Tamaño del prefijo cíclico (en muestras de la FFT)
NCP0 = 160/2048*NFFT;
% CP normal posiciones múltiplos de 7, siendo la posición del primer simbolo 0
NCP = 144/2048*NFFT; % CP resto de posiciones

% En esta versión del código, todos los PRBs están activos y agrupados en torno a la frecuencia central
% subportadoras_activas = [zeros((NFFT-Nsc)/2,1); ones(Nsc,1); zeros((NFFT-Nsc)/2-1,1)];

%% Generación de la constelación
Bn = randi([0 1], 1, Nb); % Secuencia de bits
Eb = 1; % Energía de bit. Se ajustará la potencia en el transmisor
A = sqrt(3*Eb*log2(M1*M2)/(M1^2+M1^2-2));
alf1=A*(2*(1:1:M1)-M1-1);
alf2=A*(2*(1:1:M2)-M2-1);

Bn_res = reshape(Bn,k,Nb/k)';
% Mapeo de la secuencia de bits sobre los símbolos M-QAM
if M1>2
    An1=alf1(gray2de(Bn_res(:,1:k1))+1);
else
    An1=alf1((Bn_res(:,1:k1))+1);
end
if M2>2
    An2=alf2(gray2de(Bn_res(:,k1+1:end))+1);
else
    An2=alf2((Bn_res(:,k1+1:end))+1);
end
An = An1+i*An2;
Ns = length(An); % Número de símbolos M-QAM

if ffig,
    figure; plot(unique(An),'+'); title('Constellation: ideal generated signal');
    xlabel('I'), ylabel ('Q')
end

%% Mapeo de los símbolos M-QAM sobre las subportadoras
An_symb = reshape(An,Nsc,Nsymb_OFDM);
if centralSC,
    An_symb = [An_symb(Nsc/2+1:Nsc,:);
        zeros((NFFT-Nsc),Nsymb_OFDM);
        An_symb(1:Nsc/2,:)];
else
    An_symb = [zeros(1,Nsymb_OFDM);
        An_symb(Nsc/2+1:Nsc,:);
        zeros((NFFT-Nsc)-1,Nsymb_OFDM);
        An_symb(1:Nsc/2,:)];
end

%% Creación de la forma de onda CP-OFDM
% Operación IFFT
Xn_symb = ifft(An_symb);

Xn = [];
% Se añade el CP a cada símbolo OFDM
for isimb=1:Nsymb_OFDM;
    if rem(isimb,7)==1
        Xn_symbCP0(:,isimb) = [Xn_symb(end-NCP0+1:end,isimb); Xn_symb(:,isimb)];
        % A titulo informativo, se calcula la PAPR de cada simbolo OFDM
        PAPRpsymb(isimb) = 10*log10(max(abs(Xn_symbCP0(:,isimb)).^2)./mean(abs(Xn_symbCP0(:,isimb)).^2));
        Xn = [Xn; Xn_symbCP0(:,isimb)];
    else
        Xn_symbCP(:,isimb) = [Xn_symb(end-NCP+1:end,isimb); Xn_symb(:,isimb)];
        PAPRpsymb(isimb) = 10*log10(max(abs(Xn_symbCP(:,isimb)).^2)./mean(abs(Xn_symbCP(:,isimb)).^2));
        Xn = [Xn; Xn_symbCP(:,isimb)];
    end
end

if ffig,
    figure, stem(PAPRpsymb); title('PAPR (dB)'); xlabel('Symbol');
end

Xnovs = FFTinterpolate(Xn, fs, fsovs);

%% Filtramos para hacer Spectrum Shaping
ovs = fsovs/Df/NFFT;
Xnovsflt = spectrum_shaping(Xn, fs, ovs, BWeff, tipoSS);

if ffig,
    t=[0:(length(Xnovsflt)-1)]'*1/fsovs;
    figure, plot(t,abs(Xnovsflt)); xlabel('Time (s)'); ylabel('Magnitude')
    if (length(Xnovsflt)>8e3),
        fespectros = figure;
        espectro(Xnovsflt, fsovs,fespectros); hold on; espectro(Xnovs, fsovs,fespectros);
    end
end

%% Devolvemos la señal normalizada
x = Xnovsflt/norm(Xnovsflt);

if ~centralSC,
    x = x - mean(x);
end
x  = x  / max(abs(x));

if clip.flag,

    PAPRx = 20*log10(max(abs(x))/rms(x));
    disp(sprintf('PAPR antes de clipping: %4.2f dB\n', PAPRx));

    clip_th = 10^((clip.PAPRd-PAPRx)/20);
    disp(sprintf('Muestras a las que se le aplica clipping: %d (%4.8f %% de %d)\n', sum(abs(x)>clip_th), sum(abs(x)>clip_th)/length(x),length(x)));
    x( abs(x)>clip_th) = clip_th*exp(1i*angle( x(abs(x)>clip_th)));

    PAPRx = 20*log10(max(abs(x))/rms(x));
    disp(sprintf('PAPR despues de clipping: %4.2f dB\n', PAPRx));

end

end


function y = FFTinterpolate(x, fs_y, fs_u, varargin)
%function: x_resampled = FFTinterpolate(u, fs_y, fs_u);
%x is the signal to resample
%fs_y is the desired (new) sampling rate of the output signal x_resampled
%fs_x is the sampling rate of u

if ~(fs_u == fs_y)
    N = length(x);
    [P, Q] = resample_quotients(fs_u, fs_y);
    Nn = N*P/Q;
    U = fft(x)/sqrt(N);
    if round(Nn)==Nn %Check for integer number of samples, restriction with this method
        Y(Nn,1)= 1i*1e-16;

        %Check if upsampling or downsampling
        if P > Q %Upsampling
            if mod(Nn,2)==0 %If even number of samples, easy to put back in the vector
                if mod(N,2)==0 %Even number of samples in u
                    Y(1:N/2,1) = U(1:N/2);
                    Y(Nn-N/2+1:Nn) = U(N/2+1:N);
                else
                    Y(1:floor(N/2),1) = U(1:floor(N/2));
                    Y(Nn-ceil(N/2)+1:Nn,1) = U(floor(N/2)+1:N);
                end
            else
                error('Not implemented')
            end
            y = ifft(Y)*sqrt(Nn);
        else %Downsampling
            Y(1: ceil(Nn/2)) = U(1:ceil(Nn/2));
            Y(Nn-ceil(Nn/2)+1:Nn) = U(N-ceil(Nn/2)+1:N);
            y = ifft(Y)*sqrt(Nn); %this scaling preserves norm
        end
    else
        error('Not an integer number of samples. Use some other method')
    end
else
    y = x;
end
end

function [P, Q] = resample_quotients(fs1, fs2)
%Compute the P and Q resampling coefficients to be used in FFTinterpolate
v1 = factor(fs1);
v2 = factor(fs2);
total_ind = [];
for k=1:length(v1)
    %If we can find element k of v1 in v2
    if ismember(v1(k), v2)
        %Find first index in v2 where it can be found
        ind = find(v1(k)==v2,1);
        %Remove the value at index k from v1
        total_ind = [total_ind k];
        %Remove the value at index ind from v2
        v2 = [v2(1:ind-1) v2(ind+1:end)];
    end
end
%P is the product of the remaining elements in v1
P = prod( v1(setdiff(1:length(v1), total_ind)));
Q = prod(v2);
end

function y = coarse_sync(y,xref)
cicl = floor(length(y)/length(xref));
fs = 1024*6*15e3;
[~, inds] = max(abs( xcorr(xref,y(1:length(xref))) ));
disp(sprintf('Coarse syncronization: %4.6f us',(length(xref)-inds)*1e6/fs));
y = y(length(xref)-inds+1:length(xref)-inds+length(xref)*(cicl-1));
end


function [y]=dpd_FFTFilter(Fs,Fo,BWa,x,type)

L=length(x);

switch type
    case 'LP'

        BW=ceil(L*BWa/Fs);

        plantilla_fft=zeros(L,1);
        plantilla_fft(1:1:BW,1)=ones(BW,1);
        plantilla_fft(L-BW+1:1:L,1)=ones(BW,1);

        tf=fft(x);
        y=ifft(plantilla_fft.*tf);

        %disp(sprintf('input_filterLP= %f   output_filterLP= %f',max(abs(x)),max(abs(y)) ));

    case 'BP'
        BW=ceil(L*BWa/Fs);
        Wo=round(L*Fo/Fs);
        W1=round(Wo-0.5*BW);

        plantilla_fft=zeros(L,1);
        plantilla_fft(1:1:(W1+BW))=[zeros(W1,1);ones(BW,1)];
        plantilla_fft(end:-1:end+2-(W1+BW),1)=[zeros(W1-1,1);ones(BW,1)];

        tf=fft(x);
        y=ifft(plantilla_fft.*tf);


    case 'COMPLEX_BP'
        BW=floor(L*BWa/Fs)+1;

        if (L*Fo/Fs>0)
            Wo=ceil(L*Fo/Fs);
        else
            Wo=floor(L*Fo/Fs)+L;
        end

        W1=round(Wo-0.5*BW);

        plantilla_fft=zeros(L,1);
        plantilla_fft(W1+1:1:W1+BW,1)=ones(BW,1);

        tf=fft(x);
        y=ifft(plantilla_fft.*tf);
    otherwise
end


if (isreal(x)==1)
    y=real(y);
end

end


function y=spectrum_shaping(x, fs, ovs, BW, config)
% ovs: factor de sobremuestreo después del filtro
% fs: frecuencia de muestreo antes del filtrado
% BW: ancho de banda que deja pasar la banda perfectamente plana del filtro

tipo = config.filtro;
alpha = config.param;

switch tipo
    case 'RaisedCosine'
        L = length(x);
        X = fft(x)/sqrt(L); % El escalado preserva la norma
        Xzp(L*ovs,1) = 1i*1e-16;
        Xzp(1:L/2,1) = X(1:L/2);
        Xzp(L*ovs-L/2+1:L*ovs,1) = X(L/2+1:L);
        BWflatLP = ceil(L*BW/2/fs);
        BWrolloffLP = ceil(L*alpha*BW/2/fs);
        plantilla_fft=zeros(L*ovs,1);
        plantilla_fft(1:1:BWflatLP,1)=ones(BWflatLP,1);
        plantilla_fft(L*ovs-BWflatLP+1:1:L*ovs,1)=ones(BWflatLP,1);
        plantilla_fft(BWflatLP+1:1:BWflatLP+BWrolloffLP,1)=0.5+0.5*cos(pi*(1:BWrolloffLP)/BWrolloffLP);
        plantilla_fft(L*ovs-BWflatLP:-1:L*ovs-BWflatLP-BWrolloffLP+1,1)=0.5+0.5*cos(pi*(1:BWrolloffLP)/BWrolloffLP);

        y=ifft(plantilla_fft.*Xzp)*sqrt(L*ovs);

    case 'BPideal'
        % Distorsiona un poco las constelaciones M-QAM con M alto (a partir de M = 64).
        xovs = FFTinterpolate(x, fs, fs*ovs);
        L=length(xovs);
        BWflatLP=ceil(L*0.52*BW/(fs*ovs));
        plantilla_fft=zeros(L,1);
        plantilla_fft(1:1:BWflatLP,1)=ones(BWflatLP,1);
        plantilla_fft(L-BWflatLP+1:1:L,1)=ones(BWflatLP,1);
        y=ifft(plantilla_fft.*fft(xovs))*sqrt(L*ovs);
        %y=dpd_FFTFilter(fs*ovs, 0, BW*0.52, xovs,'LP');

        %% Otros métodos de spectrum shaping usados previamente
        % %%% No me convence para canalización de 20 MHz y mu=1. Plantearlo en el
        % %%% dominio de la frecuencia, con banda de paso el ancho de banda ocupado
        % Prueba en la que se implementaba un filtro RC rn el dominio del tiempo
        % delay = 600;
        % alpha = 0.08;
        % ovs = fsovs/Df/NFFT;
        % % Filtro RC
        % rctFilt = comm.RaisedCosineTransmitFilter(Shape='Normal', ...
        %     RolloffFactor=alpha, FilterSpanInSymbols=delay, OutputSamplesPerSymbol=ovs);
        % b = coeffs(rctFilt); % Normalize filter
        % rctFilt.Gain = 1/max(b.Numerator);
        % Xnovsflt_ex = rctFilt([Xn; zeros(delay/2,1)]);
        % Xnovsflt = Xnovsflt_ex(delay/2*ovs+1:end);


        % % %% Similar a la DPD Student Competition 2017
        % % order = 8000;
        % % beta = 0.01;
        % % D = fdesign.pulseshaping(ovs,'Raised Cosine','N,Beta',order,beta);
        % % H = design(D);
        % % flt = H.numerator;
        % % delay = order/2;

        % %% Enfoque que funciona muy bien en frecuencia pero distorsiona la constelaci?n
        % filt.fs = fs;
        % filt.Nfilt = 8000*2; % filt.Nfilt = 8000;
        % delay = filt.Nfilt/2;
        % % factorFc = [1.3 1.1 1.1 1.05 1.1 1.1];
        % factorFc = [1.3 1.1 1.1 1.05 1.0667 1.1];
        % filt.Fc = factorFc(indsig)*Nsubport*Df/2;
        % % R = [0.07 0.03 0.03 0.07 0.01 0.03];
        % R = [0.07 0.03 0.03 0.03 0.03 0.03];
        % filt.R = R(indsig);
        % TM   = 'Rolloff';  % Transition Mode
        % DT   = 'Normal';   % Design Type
        % Beta = 0.4;        % Window Parameter % Beta = 0.2;
        % % Create the window vector for the design algorithm.
        % win = kaiser(filt.Nfilt+1, Beta);
        % % Calculate the coefficients using the FIR1 function.
        % flt = firrcos(filt.Nfilt, filt.Fc/(filt.fs/2), filt.R, 2, TM, DT, [], win);
        %
        % xteor_cp_RRC = FFTinterpolate(xteor_cp, fo, fs);
        % xteor_cp_RRCnofilt = xteor_cp_RRC;
        %
        % xteor_cp_RRC = ifft( fft(xteor_cp_RRC(:)).*fft(flt(:),length(xteor_cp_RRC)) );
        % xteor_cp_RRC = [xteor_cp_RRC(delay+1:end); xteor_cp_RRC(1:delay)];

        % % %% La constelaci?n sale muy bien pero el espectro no
        % % delay = 96;
        % % x_ex = [xteor_cp(end-delay+1:end); xteor_cp; xteor_cp(1:delay)];
        % % Fd = 1;
        % % Fs = ovs;
        % % alpha = 0.1;
        % % y_ex = rcosflt(x_ex, Fd, Fs, 'fir', alpha, delay); % Filtro RC
        % % xteor_cp_RRC = y_ex(2*delay .* Fs/Fd + 1:end-(2*delay .* Fs/Fd));
end

end

function  [Pxx,fvec] = espectro(x, fs,figuren)
%PSD estimate

wlen = 8e3;
olap = 5e3;
nfft = 8e3;
win = kaiser(wlen,50);
Pxx = pwelch(x, win, olap, nfft); %Welch periodogram estimate using Hanning window
Pxx = fftshift(Pxx);
N = length(Pxx);
fvec = (-fs/2:fs/N:(N-1)/N*fs/2);

Pxx = 10*log10(Pxx);
fvec = fvec/1e6;

figure(figuren);
hold on
plot(fvec,Pxx);
xlabel('MHz'); title('PSD (dB/Hz)');
end

function d = gray2de(g)
%Convierte cada fila de la matriz formada por dígitos binarios g en un vector
%columna de los valores decimales correspondientes.
% Versión adaptada de una función de Mathworks
b(:,1) = g(:,1);
for i = 2:size(g,2),
    b(:,i) = xor( b(:,i-1), g(:,i) );
end
% Convierte los bits menos significativos en los más significativos
b=fliplr(b);
%Comprueba un caso especial.
[n,m] = size(b);
if min([m,n]) < 1
    d = [];
    return;
elseif min([n,m]) == 1
    b = b(:)';
    m = max([n,m]);
    n = 1;
end;
d = (b * 2.^[0 : m-1]')';
end