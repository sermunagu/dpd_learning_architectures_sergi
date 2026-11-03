function [ACPR, ACPR2, EVM, NMSE] = analiza_medidas_5GNR_v5(xsw, med, info, fc)

% Esta funcion solo es valida para casos de una portadora o casos
% multiportadora en los que la separación entre las bandas es lo
% suficientemente grande (separacion >= 3*BW_max)

NS = length(info.NPRB);
offsets = [];
for isignal = 1:NS,
    offsets = [offsets, info.Foff(isignal)];
end
Doff = min(diff(offsets));

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


for isignal = 1:NS,
    mu = info.mu(isignal);
    Df = info.Df(isignal);
    M = info.M(isignal);
    NPRB = info.NPRB(isignal);
    Nslots = info.Nslots(isignal);
    BW = info.BW(isignal);
    NFFT = info.NFFT(isignal);
    fs = info.fs(isignal);
    fsovs = info.fsovs(isignal);
    ovs = info.ovs(isignal);
    BWeff = info.BWeff(isignal);
    seed = info.seed(isignal);
    ffig = info.ffig(isignal);
    centralSC = info.centralSC(isignal);

    if isempty(Doff)
        fsint = floor(fsovs/(NFFT*Df))*(NFFT*Df);
    else
        fsint = floor(Doff/(NFFT*Df))*(NFFT*Df);
    end
    ovs2 =  fsint/(NFFT*Df);

    % Desplazamiento a Foff
    N = length(xsw);
    xswoff = xsw.*exp(1i*2*pi*(0:N-1).'/fsovs * -info.Foff(isignal));
    medoff = med.*exp(1i*2*pi*(0:N-1).'/fsovs * -info.Foff(isignal));

    xswres = FFTinterpolate(xswoff, fsovs, fsint);
    medres = FFTinterpolate(medoff, fsovs, fsint);

    [ACPR(:,isignal), ACPR2(:,isignal), EVM(:,isignal), NMSE(:,isignal)] = analiza_medidas_OFDM(xswres, medres, NPRB,...
        mu, M, BW, fsint, ovs2, Nslots, centralSC, fc);
end


end

function [ACPR, ACPR2, EVM, NMSE] = analiza_medidas_OFDM(xsw, med, NPRB,mu,M,BW,fsovs,ovs,Nslots,centralSC,fc)

color = rand(1,3);

if ~centralSC,
    xsw = xsw - mean(xsw);
    med = med - mean(med);
end

medn = sqrt((xsw'*xsw)/(med'*med))*med;

%% Inicializacion de variables
Df = 2^mu * 15e3;  % Separación entre subportadoras (Hz)
offset = BW;
k=log2(M);              % Numero de bits por simbolo
M1 = sqrt(M);
M2 = sqrt(M);
k1 = log2(M1);
k2 = log2(M2);
Nsymb_OFDM = 14*Nslots; % Numero de simbolos OFDM
Nsc = NPRB*12;        % Numero de subportadoras activas
NFFT = 2^nextpow2(Nsc); % Tamaño de la FFT
Nsamples = NFFT*ovs;
Nb = Nsymb_OFDM*Nsc*k;
fs = NFFT*Df; % Tasa de muestreo del símbolo OFDM (Hz)
% Tamaño del prefijo cíclico (en muestras de la FFT)
NCP0 = 160/2048*NFFT;
% CP normal posiciones múltiplos de 7, siendo la posición del primer simbolo 0
NCP = 144/2048*NFFT; % CP resto de posiciones

error = medn-xsw;
if isreal(error),
    error = error+1i*1e-16;
end

% Grafica de espectro
% PSD estimate
wlen = min(8e3,length(medn));
olap = min(5e3,length(medn)/2);
nfft = min(8e3,length(medn));
win = kaiser(wlen,50);

PSDymed = pwelch(medn, win, olap, nfft);
PSDymed = fftshift(PSDymed);
PSDerror = pwelch(error, win, olap, nfft);
PSDerror = fftshift(PSDerror);
N = length(PSDymed);
f = (-fsovs/2:fsovs/N:(N-1)/N*fsovs/2);
cc = [-0.5*Nsc*Df, 0.5*Nsc*Df];
Ymedcc = 10*log10(bandpower(medn, fsovs, cc));
PSDymed_dB = 10*log10(PSDymed) - Ymedcc;
PSDerror_dB = 10*log10(PSDerror) - Ymedcc;

if ovs >= 3,
    acn = [-offset-0.5*Nsc*Df, -offset+0.5*Nsc*Df];
    Ymedacn = 10*log10(bandpower(medn, fsovs, acn));
    acp = [offset-0.5*Nsc*Df, offset+0.5*Nsc*Df];
    Ymedacp = 10*log10(bandpower(medn, fsovs, acp));
    if ovs >= 5,
        acn2 = [-2*offset-0.5*Nsc*Df, -2*offset+0.5*Nsc*Df];
        Ymedacn2 = 10*log10(bandpower(medn, fsovs, acn2));
        acp2 = [2*offset-0.5*Nsc*Df, 2*offset+0.5*Nsc*Df];
        Ymedacp2 = 10*log10(bandpower(medn, fsovs, acp2));
    end
end

fh = findobj( 'Type', 'Figure', 'Name', 'Spectrum');
if length(fh)==0
    figure('Name','Spectrum')
else
    figure(fh(1)); clf;
end

plot(f*1e-6+fc,PSDymed_dB, 'Marker', 'none',...
    'LineWidth',1), hold on, grid on,
colors = get(gca,'ColorOrder');
index  = get(gca,'ColorOrderIndex');
hold on,
if index == 1
    set(gca,'ColorOrderIndex',length(colors));
else
    set(gca,'ColorOrderIndex',index-1);
end
plot(f*1e-6+fc,PSDerror_dB, 'Marker', 'none',...
    'LineWidth',1, 'LineStyle', ':')
xlabel('Frequency (MHz)');
ylabel('Normalized PSD (dB/Hz)');
set(gca,'FontSize',12)
set(findall(gcf,'type','text'),'FontSize',12)
%set(gcf,'color','w');

ACPR = [0; 0];
ACPR2 = [0; 0];
if ovs>=3,
    ACPR = [Ymedacn; Ymedacp] - repmat(Ymedcc, 2, 1);
    if ovs >= 5,
        ACPR2 = [Ymedacn2; Ymedacp2] - repmat(Ymedcc, 2, 1);
    end
end

% Constelacion
[~, xsimb] = quita_cp(xsw, ovs, NPRB, Nslots);
[~, ysimb] = quita_cp(med, ovs, NPRB, Nslots);
if centralSC,
    vector_activo = [NFFT-Nsc/2+1:NFFT, 1:Nsc/2];
else
    vector_activo = [NFFT-Nsc/2+1:NFFT, 2:Nsc/2+1];
end
XX = fft(xsimb(1:ovs:end,:), NFFT);
XX_activo = XX(vector_activo,:);
YY = fft(ysimb(1:ovs:end,:), NFFT);
YY_activo = YY(vector_activo,:);
s_tx = XX_activo(:);
s_txn = round((sqrt(M)-1)*sqrt(2)*s_tx/max(abs(s_tx)))*sqrt(2)/3;
s_rx_med = YY_activo(:);
s_rxn_med = sqrt((s_txn'*s_txn)/(s_rx_med'*s_rx_med))*s_rx_med;

fh = findobj( 'Type', 'Figure', 'Name', 'Received constellation');
if length(fh)==0
    figure('Name','Received constellation')
else
    figure(fh(1)); hold on% clf;
end
plot(s_rxn_med, 'Marker', '.', ...
    'MarkerSize',10, ...
    'LineStyle', 'none'); hold on, grid on;
plot(s_txn, 'Color', 'g', 'Marker', '+', ...
    'MarkerFaceColor', 'g', 'MarkerSize',5, ...
    'LineStyle', 'none');
xlabel('In-phase')
ylabel('Quadrature')
set(gca,'FontSize',12)
set(findall(gcf,'type','text'),'FontSize',12)
%set(gcf,'color','w');

% Metricas de EVM
EVM = norm(s_rxn_med - s_txn)/norm(s_txn)*100;

% Metricas de NMSE
ymedn = sqrt((xsw'*xsw)/(med'*med))*med;
ymedn = ymedn - mean(ymedn);
xsw = xsw-mean(xsw);

NMSE = 20*log10((norm(ymedn-xsw)./norm(xsw)));

end

function [y, Y] = quita_cp(x, ovs, NRB, Nslots)

% OFDM parameters
NFFT = 2^(nextpow2(NRB*12));
NCP0 = 160/2048*NFFT*ovs;
NCP = 144/2048*NFFT*ovs;
Nsc = NRB*12;
Nsymb_OFDM = 14*Nslots;

Y = zeros(NFFT*ovs,Nsymb_OFDM);
for isimb=1:Nsymb_OFDM
    if rem(isimb,7)==1
        x(1:NCP0)=[];
    else
        x(1:NCP)=[];
    end

    Y(:,isimb)=x(1:NFFT*ovs);
    x(1:NFFT*ovs)=[];
end
y = Y(:);
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