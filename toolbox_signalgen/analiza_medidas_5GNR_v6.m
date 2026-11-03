function [ACPR, ACPR2, EVM, NMSE] = analiza_medidas_5GNR_v6(xsw, xswCFR, med, info, fc)

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
    
    Rs = NFFT*Df;
    if isempty(Doff)
        fsint = floor(fsovs/Rs)*Rs;
    else
        fsint = floor(Doff/Rs)*Rs;
        if fsint < Rs
            fsint = floor(fsovs/Rs)*Rs;
        end
    end
    ovs2 =  fsint/(NFFT*Df);

    % Desplazamiento a Foff
    N = length(xsw);
    xswoff = xsw.*exp(1i*2*pi*(0:N-1).'/fsovs * -info.Foff(isignal));
    xswCFRoff = xswCFR.*exp(1i*2*pi*(0:N-1).'/fsovs * -info.Foff(isignal));
    medoff = med.*exp(1i*2*pi*(0:N-1).'/fsovs * -info.Foff(isignal));

    xswres = FFTinterpolate(xswoff, fsovs, fsint);
    xswCFRres = FFTinterpolate(xswCFRoff, fsovs, fsint);
    medres = FFTinterpolate(medoff, fsovs, fsint);

    [ACPR(:,isignal), ACPR2(:,isignal), EVM(:,isignal), NMSE(:,isignal)] = ...
        analiza_medidas_OFDM(xswres, xswCFRres, medres, NPRB,...
        mu, M, BW, fsint, ovs2, Nslots, centralSC, fc, ffig);
end


end

function [ACPR, ACPR2, EVM, NMSE] = analiza_medidas_OFDM(xsw, xswCFR, med, NPRB,mu,M,BW,fsovs,ovs,Nslots,centralSC,fc, verbose)

color = rand(1,3);

if ~centralSC,
    xsw = xsw - mean(xsw);
    xswCFR = xswCFR - mean(xswCFR);
    med = med - mean(med);
end

Df = 2^mu * 15e3;  % Subcarrier separation (Hz)
BWeff = NPRB*12*Df; % Ocupied bandwidth or integration bandwidth

% Metrics computation
[ACPR, ACPR2] = compute_acpr(xswCFR, med, fsovs, ovs, BW, BWeff, fc, verbose);

EVM = evm5G(xsw, med, mu, M, Nslots, NPRB, fsovs, centralSC, verbose);

medn = sqrt((xswCFR'*xswCFR)/(med'*med))*med;
NMSE = 20*log10((norm(medn-xswCFR)./norm(xswCFR)));

end

function [y, Y] = remove_cp(x, ovs, NRB, Nslots)

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

function [ACPR1, ACPR2] = compute_acpr(x, meas, fs, ovs, BWNominal, BWMeas, fc, verbose)
%%
% This function obtains PSD for the measurement of a signal and its error
% with respect to the input, and calculates ACPR
%
% x - input signal
% meas - measured output signal
% fs - sampling frequency (Hz), not necessarily with an integer oversampling
% ovs - oversampling factor
% BWNominal - nominal bandwidht of the channel or channelization
% BWMeas - integration bandwith for the measurement of ACPR
% fc - center frequency (MHz) of the measurement for the PSD graphic

measn = sqrt((x'*x)/(meas'*meas))*meas;
error = measn-x;
if isreal(error)
    error = error+1i*1e-16;
end

% Spectrum Analyzer
wlen = 8e3;
olap = wlen/2;
nfft = 8e3;
win = flattopwin(wlen);


%% ACPR
ACPR1 = [0, 0];
ACPR2 = [0, 0];

if ovs >= 5
    acpr = comm.ACPR(SampleRate=fs,...
        MainChannelFrequency=0,...
        MainMeasurementBandwidth=BWMeas,...
        AdjacentChannelOffset=[-2*BWNominal,-BWNominal, BWNominal, 2*BWNominal],...
        AdjacentMeasurementBandwidth=BWMeas,...
        MainChannelPowerOutputPort=true,...
        AdjacentChannelPowerOutputPort=true, ...
        FFTLength='Custom', ...
        CustomFFTLength=nfft, ...
        SpectralEstimation='Specify window parameters', ...
        SegmentLength=wlen,...
        OverlapPercentage=50, ...
        Window = 'Flat Top');
    [ACPRout,~,~] = acpr(meas);
    ACPR1 = [ACPRout(2), ACPRout(3)];
    ACPR2 = [ACPRout(1), ACPRout(4)];
elseif ovs >= 3
    acpr = comm.ACPR(SampleRate=fs,...
        MainChannelFrequency=0,...
        MainMeasurementBandwidth=BWMeas,...
        AdjacentChannelOffset=[-BWNominal, BWNominal],...
        AdjacentMeasurementBandwidth=BWMeas,...
        MainChannelPowerOutputPort=true,...
        AdjacentChannelPowerOutputPort=true, ...
        FFTLength='Custom', ...
        CustomFFTLength=nfft, ...
        SpectralEstimation='Specify window parameters', ...
        SegmentLength=wlen,...
        OverlapPercentage=50, ...
        Window = 'Flat Top');
    [ACPRout,~,~] = acpr(meas);
    ACPR1 = [ACPRout(1), ACPRout(2)];
end

if verbose
    % Welch periodogram estimate using Chebyshev window with 100 dB
    % sidelobe attenuation
    [PSDmeas,f] = pwelch(measn, win, olap, nfft, fs, 'centered');
    correctionPSD = 10*log10(mean(PSDmeas(f>=-0.5*BWMeas & f <=0.5*BWMeas)));
    PSDmeas = 10*log10(PSDmeas)-correctionPSD;
    PSDerror = pwelch(error, win, olap, nfft, fs, 'centered');
    PSDerror = 10*log10(PSDerror)-correctionPSD;

    fname = 'Spectrum';
    fh = findobj('Type','Figure','Name',fname);
    if isempty(fh)
        fh = figure('Name',fname);
    else
        figure(fh(1));
    end
    ax = gca;
    hold(ax,'on');

    plot(ax, f*1e-6+fc,PSDmeas, 'Marker', 'none','LineWidth',1),
    grid(ax,'on');
    colors = get(ax,'ColorOrder');
    index  = get(ax,'ColorOrderIndex');
    if index == 1
        set(ax,'ColorOrderIndex',length(colors));
    else
        set(ax,'ColorOrderIndex',index-1);
    end

    plot(ax, f*1e-6+fc,PSDerror, 'Marker', 'none',...
        'LineWidth',1, 'LineStyle', ':')
    xlabel(ax, 'Frequency (MHz)');
    ylabel(ax, 'Normalized PSD (dB/Hz)');
    set(ax,'FontSize',12)
    set(findall(gcf,'type','text'),'FontSize',12)
    %set(gcf,'color','w');
    hold on
end
end

function evm = evm5G(xsw, med, mu, M, Nslots, NRB, fs, centralSC, verbose)
%%
% This function calculates EVM for the measurement of a signal with 5G-NR format
%
% xsw - input (ideal) signal
% med - measured output signal
% mu - 5G-NR Numerology
% M - modulation index
% Nslots - number of slots of the 5G-NR signal
% NRB - number of active resourse blocks of the 5G-NR signal
% fs - sampling frequency (Hz), not necessarily with an integer oversampling

if nargin ==7,
    verbose = 1;
end

%% Initialization
Df = 2^mu * 15e3;                   % Numerology
Nsc = NRB*12;      % Number of active subcarriers
NFFT = 2^(nextpow2(Nsc));    % Size of the FFT operations
Rs = NFFT*Df;
fsint = floor(fs/Rs)*Rs;
% Sampling frequency with integer oversampling
ovs =  fsint/Rs;

% Resampling to consider an integer oversampling
xsw = FFTinterpolate(xsw, fs, fsint);
med = FFTinterpolate(med, fs, fsint);

%% Constellation
[~, x_symb] = remove_cp(xsw, ovs, NRB, Nslots);
[~, y_symb] = remove_cp(med, ovs, NRB, Nslots);
if centralSC,
    active_sc = [NFFT-Nsc/2+1:NFFT, 1:Nsc/2];
else
    active_sc = [NFFT-Nsc/2+1:NFFT, 2:Nsc/2+1];
end
XX = fft(x_symb(1:ovs:end,:), NFFT);
XX_active = XX(active_sc,:);
YY = fft(y_symb(1:ovs:end,:), NFFT);
YY_active = YY(active_sc,:);
s_tx = XX_active(:);
s_txn = round((sqrt(M)-1)*sqrt(2)*s_tx/max(abs(s_tx)))*sqrt(2)/3;
s_rx_med = YY_active(:);
s_rxn_med = sqrt((s_txn'*s_txn)/(s_rx_med'*s_rx_med))*s_rx_med;

if verbose
    fname = 'Received constellation';
    fh = findobj('Type','Figure','Name',fname);
    if isempty(fh)
        fh = figure('Name',fname);
    else
        figure(fh(1));
    end
    ax = gca;
    hold(ax,'on');

    plot(ax, s_rxn_med, 'Marker', '.', ...
        'MarkerSize',10, ...
        'LineStyle', 'none'); hold on, grid on;
    plot(ax, s_txn, 'Color', 'g', 'Marker', '+', ...
        'MarkerFaceColor', 'g', 'MarkerSize',5, ...
        'LineStyle', 'none');
    axis(ax, 'equal'), axis(ax, 'square')
    xlabel(ax, 'In-phase')
    ylabel(ax, 'Quadrature')
    set(ax,'FontSize',12)
    set(findall(gcf,'type','text'),'FontSize',12)
    %set(gcf,'color','w');

end

% EVM
evm = norm(s_rxn_med - s_txn)/norm(s_txn)*100;

end
