%% Store measurement performance metrics
performance.ACPR = ACPR;       % Adjacent Channel Power Ratio
performance.EVM = EVM;         % Error Vector Magnitude
performance.NMSE = NMSE;       % Normalized Mean Square Error

%% Store measurement signals and related data
meas.y = y;                    % Measured output signal
meas.x = x;                    % Input signal to the system
meas.u = u;                    % Original reference input
meas.performance = performance; 
meas.xCFR = xCFR;              % CFR-processed input signal
meas.data = measdata;          % Raw measurement data
meas.w = [];                    % ILC weight (empty here)
meas.Gin = Gin;                % Input gain applied
meas.Lout = Lout;              % Output gain applied

%% Compute additional signal metrics
meas.Pin = dBm(x) + Gin;       % Input power including gain
meas.Pout = dBm(y);            % Output power
meas.PAPRx = PAPR(x);          % PAPR of input signal
meas.PAPRxCFR = PAPR(xCFR);    % PAPR after CFR processing
meas.Gdpd = dBm(x) - dBm(u);   % DPD gain

%% Calculate system gain
[Gm, Gcm, Phc] = calculate_Gc(y, x*10^(Gin/20), false);
meas.Gsist = Gm + meas.Gdpd;   % Total system gain including DPD
meas.Gavg = Gm;                 % Average gain
meas.Gc = Gcm;                  % Correction gain from CFR
meas.G0 = G0;                   % Target gain


%% Append this measurement to results
meas_out = [meas_out meas];

%% Update figures with the latest measurement
if exist('filenamedate', 'var') && ~isempty(filenamedate)
    meas2figure(meas_out, fullfile('results', ['experiment' filenamedate]));
else
    meas2figure(meas_out);
end
