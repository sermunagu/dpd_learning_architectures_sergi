%% Prepare workspace
addpath('toolbox');
addpath('toolbox_signalgen');
addpath('confset');
clearvars -except TRx waveform_id; close all; clc;
inline_functions

platform = 'ADRV';  % 'ADRV' or 'RFSoC'

switch upper(platform)
	case 'ADRV'
		addpath('toolbox_ADRV');
		if ~exist('TRx','var')
			connectADRV(2600);
			global TRx
		end
		% disableRFADRV(TRx); % to disableRF
		% TRx.disconnect(); % to release the handler
		% TRx = reconnectADRV(2600); % to reconnect without programming FPGA
	case 'RFSOC'
		addpath('toolbox_RFSoC');
end

% power on:
% fuenteDC(1,[],-15);
% fuente_Doherty('on')
% fuenteK_monitorI1
%
% power off:
% fuente_Doherty('off')
% fuenteDC(1,[],0);

%% Signal configuration
waveform_id = 8;                 % Select waveform 1..8
config_signal_master_5waveforms
[usw, ~, info_signal] = genera_5GNR_multicarrier_v5(info_signal);

u = clipping_PAPR_ICF(usw, 8, mask, 5);
fs = info_signal.fsovs(1); % Must be: 491.52e6;
info_signal.ffig = [true true];

%% Experiment configuration
fc = 2.6e9;
Lout = 78.60-6-10+6-6; %Doherty
Gin = 60.8-6-6; %Doherty
Ncycles = 16; % Number of signal repetitions to capture
captureTime =Ncycles*length(u)/fs*1e3;

RMSin = -22;
maxRMSx = RMSin + 3;   % Safety: max average power of the transmitted signal (dBm)
maxPEPx = RMSin + 14;  % Safety: max peak power of the transmitted signal (dBm)
gainMode = 'average';  % 'average', 'compressed', 'fixed'
Gfixed = 63.5;            % Ganancia fija (configurable)

Niter = 15;
mu = zeros(1,Niter);

DLmethod = 'ILC'; % 'DLA' / 'ILC' / 'ILA'

measureWithoutDPDAtEnd = false;  % Perform one final measurement without DPD
deleteIntermediateSignals = true;  % Delete all intermediate signals
saveLastMeasurement = true;  % Save last measurement in an independent file
stopOnConvergence = false;  % Stop iterations when ACPR convergence is reached
ACPRthreshold = 0.01;     % Convergence threshold (dB)

%% Initialization
meas_out = [];
filenamedate = datestr(clock,30);
if ~exist('results', 'dir'), mkdir('results'); end
prev_ACPR = inf;
u = scale_dBm(u, RMSin);

switch DLmethod
	case 'ILC'
		U_w=zeros(length(u),1);
	case 'DLA'
		model_configuration_B
		[U, ~, Rmat] = model_gmp_generate_X(u, u, dpd_model);
		[f,c]=size(U);
		w = zeros(c,1);
		dw = zeros(c,1);
		normU = vecnorm(U);
		Un = U*diag(normU.^-1);
	case 'ILA'
		model_configuration_B
		[U, ~, Rmat] = model_gmp_generate_X(u, u, dpd_model);
		w = zeros(size(U,2),1);
end

for iter=1:Niter
	fprintf("Iteration %d\n",iter);

	switch DLmethod
		case 'ILC'
			x = u-U_w;
		case {'DLA', 'ILA'}
			x = u-U*w;
	end

	xCFR = CFR_hard(x,15);

	fprintf("dBm(x) = %4.1f dBm, PAPR(x) = %4.1f dB, PEP(x)=dBm(x)+PAPR(x) = %4.1f dBm\n",dBm(xCFR),PAPR(xCFR),dBm(xCFR)+PAPR(xCFR));

	check_tx_safety(xCFR, maxRMSx, maxPEPx); % Stops before transmitting an unsafe signal
	[y, measdata]= measureADRV(xCFR, captureTime);
	y = full_sync_5G(y, u, fs, info_signal.BW, info_signal.Foff);
	y = y*10^(Lout/20); y = y(:); y = y-mean(y);

	[~, ~, EVM, NMSE] = analiza_medidas_5GNR_v6(usw, u, y, info_signal, fc);
	[ACPR, NMSE] = ACPROFDM(u, y, fs,  info_signal.BW, info_signal.BWeff, info_signal.Foff);

	[G, Gc, Phc] = calculate_Gc(y,xCFR);
	gc = 10^(Gc/20);
	g = 10^(G/20);


	if iter == 1, switch lower(gainMode), case 'average', G0 = G; case 'compressed', G0 = Gc; case 'fixed', G0 = Gfixed; end, end
	g0 = 10^(G0/20);

	e = y/g0-u;
	e = spectrumMask(e, maskerr);
	mu0 = 1;
	mu(iter)=mu0*10^(G0/20)/10^(G/20);

	switch DLmethod
		case 'ILC'
			U_w = U_w + mu(iter) * e;
			w = []; % for compatibility
		case 'DLA'
			%dw = (inv(U'*U)*U')*e;
			dw = diag(normU.^-1)*(inv(Un'*Un)*Un')*e;
			w = w + mu(iter) * dw;
		case 'ILA'
			% Post-inverse trained from yn = y/g0 to xCFR, with the same structure
			% as the predistorter (xCFR = yn - Y*wpost), then copied to the DPD
			yn = y/g0;
			Y = model_gmp_generate_X(yn, yn, dpd_model);
			normY = vecnorm(Y);
			Yn = Y*diag(normY.^-1);
			wpost = diag(normY.^-1)*(inv(Yn'*Yn)*Yn')*(yn-xCFR);
			mu(iter) = mu0; % Gain already normalized by g0: mu0 only damps the copy
			w = w + mu(iter) * (wpost - w);
	end

	meas.descr = [DLmethod ' iter ' num2str(iter) ' RMS ' num2str(RMSin) ];
	meas.mu = mu(iter);             % Learning rate for this iteration
	store_data_and_show_performance
	update_figures

	% Stop if ACPR convergence is reached
	if stopOnConvergence && iter > 1
		if abs(prev_ACPR(end/2) - ACPR(end/2)) < ACPRthreshold
			fprintf('Stopping early: ACPR improvement < %.2f dB\n', ACPRthreshold);
			break;
		end
	end

	prev_ACPR = ACPR;
end


%% One last measurement without DPD
if measureWithoutDPDAtEnd
	% Perform one final measurement without DPD:
	% u is sent at the same average power as x in the last iteration
	fprintf("Final measurement without DPD\n");

	x = scale_dBm(u, dBm(x));
	xCFR = CFR_hard(x,15);

	fprintf("dBm(x) = %4.1f dBm, PAPR(x) = %4.1f dB, PEP(x)=dBm(x)+PAPR(x) = %4.1f dBm\n",dBm(xCFR),PAPR(xCFR),dBm(xCFR)+PAPR(xCFR));

	check_tx_safety(xCFR, maxRMSx, maxPEPx); % Stops before transmitting an unsafe signal
	[y, measdata]= measureADRV(xCFR, captureTime);
	y = full_sync_5G(y, u, fs, info_signal.BW, info_signal.Foff);
	y = y*10^(Lout/20); y = y(:); y = y-mean(y);

	[~, ~, EVM, NMSE] = analiza_medidas_5GNR_v6(usw, u, y, info_signal, fc);
	[ACPR, NMSE] = ACPROFDM(u, y, fs,  info_signal.BW, info_signal.BWeff, info_signal.Foff);

	meas.descr = ['No DPD after ' DLmethod ' iter ' num2str(iter) ' RMS ' num2str(RMSin) ];
	meas.mu = 0;                    % No learning update
	store_data_and_show_performance
	update_figures
end

%% Clean data and save
clear ans ACPR ACPR2 c data dBm dBminst e EVM f fh fig* imed iter maxdBm meas NMSE PAPR performance scale_dBm u U us w x y filename dw uCFR xCFR  measdata U_w Y Yn yn normY wpost;
exp_config = struct(G=G, G0=G0, Gc=Gc, Lout=Lout, ...
	Ncycles=Ncycles, Niter=Niter, PAPRd=PAPRd, Phc=Phc, ...
	RMSin=RMSin, maxRMSx=maxRMSx, maxPEPx=maxPEPx, ...
	captureTime=captureTime, fc=fc, fs=fs, ...
	g=g, g0=g0, gc=gc, mu=mu, waveform_id=waveform_id, ...
	DLmethod=DLmethod, gainMode=gainMode, Gfixed=Gfixed, ...
	measureWithoutDPDAtEnd=measureWithoutDPDAtEnd, ...
	deleteIntermediateSignals=deleteIntermediateSignals, ...
	saveLastMeasurement=saveLastMeasurement, ...
	stopOnConvergence=stopOnConvergence, ACPRthreshold=ACPRthreshold);



% Index of the last measurement with DPD (the final one without DPD is optional)
iLastDPD = length(meas_out) - measureWithoutDPDAtEnd;

% Delete all the intermediate signals (keep first, last with DPD and final without DPD)
if deleteIntermediateSignals
	for i = 2:(iLastDPD-1)
		meas_out(i).x = [];
		meas_out(i).y = [];
		meas_out(i).u = [];
		meas_out(i).xCFR = [];
	end
end

save(['results/experiment' filenamedate],'meas_out','exp_config','filenamedate', 'info_signal')

%% Save just u-x for modeling.
if saveLastMeasurement
	x = meas_out(iLastDPD).u;
	y = meas_out(iLastDPD).x;
	description = ['Measurement taken from experiment' filenamedate ' for DPD modeling.'];
	save(['results' filesep 'experiment' filenamedate '_xy'],'x','y','fs','info_signal','exp_config','description');
end

%% PDF report (results/experiment<filenamedate>/experiment<filenamedate>_report.pdf)
generate_learning_report(filenamedate, exp_config, info_signal);

