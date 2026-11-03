function y_out = full_sync_5G(y_measured, x_ref, fs, BW, Foff)
% FULL_SYNC_5G_FINAL
%
% Processing stages:
% 1. Coarse synchronization using cross-correlation.
% 2. Fine synchronization applied independently to each cycle.
% 3. Averaging of synchronized cycles to reduce noise.
% 4. Spectrum estimation using the provided spectrumest function.
%
% Inputs:
% y_measured  -> captured signal
% x_ref       -> reference signal
% fs          -> sampling frequency
% BW          -> bandwidth of each band
% Foff        -> frequency offset of each band
%
% Output:
% y_out       -> synchronized and averaged signal

%% ---------------- DEBUG CONTROL ----------------
% Enable/disable all debug plots
plotdebug = false;

%% ---------------- INPUT DEFAULTS ----------------
if nargin < 5
    Foff = 0;
end

if nargin < 4
    BW = fs;
end

%% ---------------- SIGNAL PREPARATION ----------------
% Ensure column vectors
x = x_ref(:);
y = double(y_measured(:));
L = length(x);

% Power measurement function (reference impedance: 100 Ohms)
calc_dBm = @(s) 10*log10(norm(s).^2 / (100 * length(s))) + 30;
Pin = calc_dBm(y);

%% --- STAGE 1: COARSE SYNCHRONIZATION ---
% Determine how many complete cycles exist in the capture
cicl = floor(length(y) / L) - 1;

if cicl < 1
    error('Input signal is too short to contain a full cycle.');
end

% Cross-correlation between measured signal and reference
[r, lags] = xcorr(y, x);

% Detect correlation peaks using the 0.996 threshold
[~, locs] = findpeaks(abs(r), 'MinPeakHeight', max(abs(r)) * 0.996);

% Keep only peaks corresponding to positive lags
valid_locs = locs(lags(locs) >= 0);

if isempty(valid_locs)
    error('No correlation peaks found in positive lags.');
end

% First valid peak gives the synchronization start index
start_index = lags(valid_locs(1)) + 1;

% Segment the signal into a matrix [Samples x Cycles]
y_segmented = reshape(y(start_index : start_index + (cicl * L) - 1), L, cicl);

%% --- STAGE 2: INDIVIDUAL FINE SYNCHRONIZATION ---
fprintf('Applying Fine Sync to %d cycles...\n', cicl);

y_corrected_matrix = zeros(L, cicl);

% FFT of the ideal reference
X = fftshift(fft(x));

% Frequency vector
df = fs/L;
f = ((0:L-1) - L/2).' * df;

% Detect valid subcarriers inside each band
factorstd = 2;
valid_bins = [];

for b = 1:length(BW)
    
    bins_band = find((abs(f - Foff(b)) <= BW(b)/2) & ...
                     (abs(X) > (mean(abs(X)) + factorstd*std(abs(X)))));
                 
    valid_bins = [valid_bins; bins_band];
end

%% -------- DEBUG PLOT: VALID BINS OVER FFT --------
if plotdebug
    
    XdB = 20*log10(abs(X) + eps);

    figure
    plot(f/1e6, XdB, 'b')
    hold on
    plot(f(valid_bins)/1e6, XdB(valid_bins), 'r.', 'MarkerSize', 12)

    xlabel('Frequency (MHz)')
    ylabel('Magnitude (dB)')
    title('FFT with Valid Bins Highlighted')
    legend('Full Spectrum','Valid Bins')
    grid on

end

%% -------- PER-CYCLE FINE SYNCHRONIZATION --------
for k = 1:cicl
    
    % Current cycle
    y_cycle = y_segmented(:, k);
    
    % FFT of measured cycle
    Y = fftshift(fft(y_cycle));
    
    % Phase difference between measured and reference spectra
    phase_diff = angle(Y) - angle(X);
    
    % Unwrap phase only on the selected valid bins
    phase_diff_unw = unwrap(phase_diff(valid_bins));

    % Linear fit:
    % slope     -> fractional delay
    % intercept -> phase rotation
    coeffs = polyfit(valid_bins, phase_diff_unw, 1);
    
    % Reconstruct phase correction curve
    phase_curve = polyval(coeffs, (1:L)');

    % Apply phase correction in frequency domain
    Y_corr = Y .* exp(-1i * phase_curve);

    % Return corrected signal to time domain
    y_corrected_matrix(:, k) = ifft(ifftshift(Y_corr));

    %% -------- DEBUG PLOTS --------
    if plotdebug
        
        figure

        % -------- SUBPLOT 1: Spectrum with selected bins --------
        subplot(2,1,1)

        YdB = 20*log10(abs(Y)+eps);

        plot(1:L, YdB, 'b')
        hold on
        plot(valid_bins, YdB(valid_bins), 'r.', 'MarkerSize',12)

        xlabel('FFT Bin')
        ylabel('Magnitude (dB)')
        title('Active Band and Selected Valid Bins')
        legend('Spectrum','Valid bins')
        grid on


        % -------- SUBPLOT 2: Phase difference and linear fit --------
        subplot(2,1,2)

        plot(valid_bins, phase_diff_unw, 'bo')
        hold on
        plot(valid_bins, polyval(coeffs, valid_bins), 'r', 'LineWidth',2)

        xlabel('FFT Bin')
        ylabel('Phase (rad)')
        title('Phase Difference and Linear Fit')
        legend('Phase difference','Linear fit')
        grid on
        
    end

end

%% --- STAGE 3: AVERAGING & NORMALIZATION ---
% Average synchronized cycles
y_averaged = mean(y_corrected_matrix, 2);

% Restore original input power level
Pout = calc_dBm(y_averaged);
y_out = y_averaged * 10^((-Pout + Pin) / 20);

%% --- STAGE 4: SPECTRUM ESTIMATION ---
% Create figure for PSD
fig_psd = getOrCreateFigure('Final Sync - Spectrum Analysis', true);

% Compute PSD using Welch method
[Pxx, fvec] = spectrumest(y_out, fs, true, 'welch', fig_psd);

title(['Final PSD - Averaged over ' num2str(cicl) ' cycles'])
grid on

%% -------- FINAL METRICS --------
nmse_db = 20 * log10(norm(y_out/norm(y_out) - x/norm(x)) / norm(x/norm(x)));

fprintf('Synchronization Successful!\n')
fprintf('  - Cycles Averaged: %d\n', cicl)
fprintf('  - Final NMSE: %4.2f dB\n', nmse_db)

end