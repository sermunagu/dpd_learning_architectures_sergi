function [safetyTable, limits] = check_dpd_signal_safety( ...
    dpd, referenceSignal, cfrPaprLimit_dB, averagePowerMargin_dB, peakPowerMargin_dB)
%CHECK_DPD_SIGNAL_SAFETY Preflight DPD waveforms before PA transmission.
%
% Safety is evaluated on the CFR-processed waveform, because that is the
% signal passed to measureADRV. Raw metrics are also recorded for diagnosis.

if nargin < 3 || isempty(cfrPaprLimit_dB)
    cfrPaprLimit_dB = 15;
end
if nargin < 4 || isempty(averagePowerMargin_dB)
    averagePowerMargin_dB = 0.5;
end
if nargin < 5 || isempty(peakPowerMargin_dB)
    peakPowerMargin_dB = 1.25;
end

averagePower_dBm = @(z) 10*log10(mean(abs(z(:)).^2)/100) + 30;
papr_dB = @(z) 10*log10(max(abs(z(:)).^2)/mean(abs(z(:)).^2));

referenceSignal = referenceSignal(:);
limits.referenceAveragePower_dBm = averagePower_dBm(referenceSignal);
limits.referencePapr_dB = papr_dB(referenceSignal);
limits.referencePeakPower_dBm = ...
    limits.referenceAveragePower_dBm + limits.referencePapr_dB;
limits.maxAveragePower_dBm = ...
    limits.referenceAveragePower_dBm + averagePowerMargin_dB;
limits.maxPapr_dB = cfrPaprLimit_dB + 0.05; % Numerical tolerance after CFR.
limits.maxPeakPower_dBm = ...
    limits.referencePeakPower_dBm + peakPowerMargin_dB;

nSignals = numel(dpd);
model = strings(nSignals, 1);
raw_average_dBm = zeros(nSignals, 1);
raw_papr_dB = zeros(nSignals, 1);
raw_peak_dBm = zeros(nSignals, 1);
tx_average_dBm = zeros(nSignals, 1);
tx_papr_dB = zeros(nSignals, 1);
tx_peak_dBm = zeros(nSignals, 1);
safe = false(nSignals, 1);

for kk = 1:nSignals
    raw = dpd(kk).yvalmod(:);
    tx = CFR_hard(raw, cfrPaprLimit_dB);

    model(kk) = string(dpd(kk).modeltype);
    raw_average_dBm(kk) = averagePower_dBm(raw);
    raw_papr_dB(kk) = papr_dB(raw);
    raw_peak_dBm(kk) = raw_average_dBm(kk) + raw_papr_dB(kk);
    tx_average_dBm(kk) = averagePower_dBm(tx);
    tx_papr_dB(kk) = papr_dB(tx);
    tx_peak_dBm(kk) = tx_average_dBm(kk) + tx_papr_dB(kk);

    metrics = [raw_average_dBm(kk), raw_papr_dB(kk), raw_peak_dBm(kk), ...
        tx_average_dBm(kk), tx_papr_dB(kk), tx_peak_dBm(kk)];
    safe(kk) = all(isfinite(metrics)) && ...
        tx_average_dBm(kk) <= limits.maxAveragePower_dBm && ...
        tx_papr_dB(kk) <= limits.maxPapr_dB && ...
        tx_peak_dBm(kk) <= limits.maxPeakPower_dBm;
end

safetyTable = table(model, raw_average_dBm, raw_papr_dB, raw_peak_dBm, ...
    tx_average_dBm, tx_papr_dB, tx_peak_dBm, safe);
end
