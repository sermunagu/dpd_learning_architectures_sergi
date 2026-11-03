function transmitADRV(TRx, u, txChannel, txAtten, orxGain)
% transmitADRV  Transmits waveform u
%
% Inputs
%   TRx          → connected TRx object
%   u            → complex baseband waveform
%   captureTime  → capture duration in ms
%   txChannel    → 1,2,3 or 4 (select TX1–TX4)
%   txAtten      → (optional) Tx attenuation, default = 10
%   orxGain      → (optional) ORx gain, default = 255
%
% Output
%   fu → captured samples

    %% Default optional parameters
    if nargin < 4 || isempty(txAtten)
        txAtten = 10;
    end

    if nargin < 5 || isempty(orxGain)
        orxGain = 255;
    end

    %% Normalize baseband RMS to -15 dBFS
    u = u / rms(abs(u)) * 10^(-15/20);

    fprintf('Input levels (dBFS) [Peak RMS]:\n');
    disp(20*log10([max(abs(u)) rms(u)]));

    %% Select TX channel dynamically
    switch txChannel
        case 1
            txEnum = adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1;
        case 2
            txEnum = adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX2;
        case 3
            txEnum = adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX3;
        case 4
            txEnum = adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX4;
        otherwise
            error('txChannel must be 1, 2, 3 or 4');
    end

    %% TX configuration
    TRx.SelTxChannels = double(txEnum);
    pause(0.5);

    TRx.TxAttenSet(txAtten*1000, double(txEnum));

    %% ORx gain (siempre ORX1 aquí, puedes hacerlo parametrizable si quieres)
    TRx.OrxGainSet(orxGain, ...
        double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX1));

    %% Transmit
    TRx.transmit(u, 'IMMEDIATE');

end
