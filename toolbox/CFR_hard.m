function y = CFR_hard(x, PAPRd, verbose)
% CFR_HARD Hard-clipping Crest Factor Reduction
%
% Inputs
%   x        : complex baseband input signal
%   PAPRd    : target PAPR in dB
%   verbose  : enable logging (true/false)
%
% Output
%   y        : output signal after CFR

if nargin < 3
    verbose = true;
end

%% --- Utility functions ---

% Average power in dBm
avg_dBm = @(s) 10*log10(rms(s).^2/100) + 30;

% PAPR computation
calc_PAPR = @(s) 20*log10(max(abs(s))/rms(s));

% Scale signal to target average power
scale_dBm = @(s, P) s * 10^((P - avg_dBm(s))/20);

%% --- Initial metrics ---
Pin_avg  = avg_dBm(x);
PAPR_in  = calc_PAPR(x);

%% --- CFR processing ---
if PAPR_in > PAPRd

    % Normalize signal to unit peak
    x = x / max(abs(x));

    % Recompute PAPR after normalization
    PAPR_norm = calc_PAPR(x);

    % Compute clipping threshold
    clip = 10^((PAPRd - PAPR_norm)/20);

    % Identify samples exceeding threshold
    idx_clip = abs(x) > clip;
    nClip = sum(idx_clip);
    pctClip = 100 * nClip / length(x);

    % Apply hard clipping while preserving phase
    x(idx_clip) = clip .* exp(1i * angle(x(idx_clip)));

    % Restore original average power
    y = scale_dBm(x, Pin_avg);

else
    y = x;
    nClip = 0;
    pctClip = 0;
end

%% --- Output metrics ---
Pout_avg = avg_dBm(y);
PAPR_out = calc_PAPR(y);

%% --- Logging ---
if verbose
    fprintf('Hard CFR Analysis:\n');
    fprintf('  Input PAPR: %4.2f dB | Target PAPR: %4.2f dB | Output PAPR: %4.2f dB\n', ...
        PAPR_in, PAPRd, PAPR_out);

    fprintf('  Clipped samples: %d (%4.4f %% of %d)\n', ...
        nClip, pctClip, length(x));
end

end