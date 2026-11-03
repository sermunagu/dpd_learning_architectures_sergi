%% Signal configuration

info_signal = struct();

% ----- Core waveform parameters -----
info_signal.Df      = [15e3 15e3];     % Subcarrier spacing (Hz)
info_signal.M       = [64 64];      % QAM order (square constellation)
info_signal.NPRB    = [106 106];      % Number of active PRBs (12 subcarriers each)
info_signal.BW      = [20e6 20e6];    % Channel bandwidth (Hz)
info_signal.Nslots  = [1 1];        % Number of slots (14 OFDM symbols per slot)
info_signal.ovs     = [16 16];        % Oversampling factor (integer)
info_signal.Foff    = [-40e6 40e6];

% ----- Random generation -----
info_signal.seed = [1000 1001];        % RNG seed

% ----- Subcarrier configuration -----
info_signal.centralSC = [0 0];      % 0 → central subcarrier unused

% ----- Clipping configuration -----
info_signal.fclipCarrier  = [0 0];  % Per-carrier clipping enable
info_signal.fclip         = 0;  % Global clipping enable
info_signal.PAPRdCarrier  = [10.5 10.5]; % Target PAPR per carrier (dB)
info_signal.PAPRd         = info_signal.PAPRdCarrier;

% ----- Spectrum shaping -----
info_signal.SpectrumShaping      = {'BPideal','BPideal'}; % Options: 'BPideal','RaisedCosine'
info_signal.SpectrumShapingParam = [0 0];         % Parameter for shaping filter

% ----- Visualization -----
info_signal.ffig = [false false];           % Enable figures


%% Independent test parameters
PAPRd = 12;
RMSin = 0;
