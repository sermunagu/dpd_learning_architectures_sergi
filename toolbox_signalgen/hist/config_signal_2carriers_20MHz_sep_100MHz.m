%% 5G-NR Dual Carrier Configuration (20MHz @ 100MHz separation)

% Basic constants
fs_adrv = 122.88e6; % Sampling rate for mu=2 (60kHz) with NFFT 2048
ovs_adrv = 4;        % Oversampling factor
fsovs_adrv = 491.52e6; % Target final sample rate for ADRV902x

info_signal = struct();

% --- Carrier-Specific Parameters (Vectors or Cells) ---
% We define 2 carriers (Ncarriers = 2)

info_signal.Df      = [60e3, 60e3];       % SCS 60kHz (mu=2)
info_signal.M       = [256, 256];         % 256-QAM
info_signal.NPRB    = [24, 24];           % 24 PRBs per carrier (~20MHz)
info_signal.BW      = [20e6, 20e6];       % Nominal BW
info_signal.Nslots  = [4, 4];             % 4 slots = 1ms for mu=2
info_signal.NFFT    = [2048, 2048];       % NFFT per carrier

% --- Global Sampling configuration ---
% Essential: Both carriers must result in the same fsovs to be summed
info_signal.ovs     = [ovs_adrv, ovs_adrv]; 
info_signal.fsovs   = fsovs_adrv;         % Final rate: 491.52 MHz

% --- Frequency Offsets ---
info_signal.Foff    = [-40e6, 40e6];      

% --- Shaping & Clipping (Individual) ---
% Note: SpectrumShaping must be a Cell Array when Ncarriers > 1
info_signal.SpectrumShaping      = {'BPideal', 'BPideal'}; 
info_signal.SpectrumShapingParam = [0, 0];
info_signal.fclipCarrier         = [0, 0]; 
info_signal.PAPRdCarrier         = [10.5, 10.5];

% --- Other Individual Parameters ---
info_signal.seed      = [1000, 1001];
info_signal.centralSC = [0, 0];   % 0 -> Central subcarrier disabled
info_signal.ffig      = [1, 1];   % 1 -> Show plots for each carrier

% --- Global Clipping (Applied to the summed signal) ---
info_signal.fclip = 0;            % Global clipping disabled
info_signal.PAPRd = 12;

