function [fu, measdata] = measureADRV(u, captureTime)
% measureADRV  Transmits waveform u and captures ORx samples
%
% Inputs
%   TRx          → connected TRx object
%   u            → complex baseband waveform
%   captureTime  → capture duration in ms
%   txAtten      → (optional) Tx attenuation, default = 10
%   orxGain      → (optional) ORx gain, default = 255
%
% Output
%   fu → captured samples
global TRx;

dBm = @(x) 10*log10(rms(x).^2/100)+30;
scale_dBm = @(x,P) x*10^((P-dBm(x))/20);

%% Default optional parameters
if nargin < 4 || isempty(txAtten)
    txAtten = 10;
end

if nargin < 5 || isempty(orxGain)
    orxGain = 255;
end

%% Normalize baseband RMS to -15 dBFS
% Performance is much better changing the signal amplitude rather than
% changing the attenuator.
%     Pout = dBm(u);
%     target_dBFS = -15;
%     u = u / rms(u) * 10^(target_dBFS/20);
%     CalOffset = 4.6;
%     hwAtten = 10 + target_dBFS + CalOffset - Pout;
%
%     fprintf('Input levels (dBFS) [Peak RMS]:\n');
%     disp(20*log10([max(abs(u)) rms(u)]));
%
%     if hwAtten < 0
%         warning('Target power is too high for -15 dBFS. Setting HW Attenuation to 0.');
%         hwAtten = 0;
%     elseif hwAtten > 41.95
%         warning('Target power is too low. Setting HW Attenuation to max (41.95).');
%         hwAtten = 41.95;
%     end
%
%     fprintf('\n--- TX Configuration ---\n');
%     fprintf('Digital Level: %.2f dBFS RMS\n', 20*log10(rms(u)));
%     fprintf('Original Signal Power: %.2f dBm\n', Pout);
%     fprintf('Calculated HW Attenuation: %.2f dB\n', hwAtten);

CalOffset = 4.65-0.15- 0.6;    % calibrado experimentalmente
dBFS_target = dBm(u) + txAtten - CalOffset;
u = u / rms(abs(u)) * 10^(dBFS_target/20);

peak_dBFS = 20*log10(max(abs(u)));

if peak_dBFS > 0
    error('Signal peak exceeds 0 dBFS: %.2f dBFS', peak_dBFS);
end

fprintf('Input levels (dBFS) [Peak: %.2f dB, RMS: %.2f dB]\n', peak_dBFS, 20*log10(rms(u)));

%% TX/RX configuration
TRx.TxAttenSet(round(txAtten*1000), ...
    double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1));

TRx.OrxGainSet(orxGain, ...
    double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX2));

%% Transmit
TRx.transmit(u, 'IMMEDIATE');

%% Capture
fu = TRx.capture(TRx.SelRxChannels, captureTime, 'IMMEDIATE');

fprintf('Captured levels (dBFS) [Peak: %.2f dB, RMS: %.2f dB]\n', 20*log10(max(abs(fu))), 20*log10(rms(fu)));

fu = fu(:);

CalOutOffset = -17.8128;

fu = scale_dBm(fu, dBm(fu)+CalOutOffset);

measdata = measure_power_supplies();

end
