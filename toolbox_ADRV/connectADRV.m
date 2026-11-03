function connectADRV(centerFrequency)
% connectADRV  Initializes connection with ADRV board and returns TRx object
% All parameters are fixed internally.
global TRx

%% Default value if not provided
if nargin < 1 || isempty(centerFrequency)
    centerFrequency = 3500; % Default center frequency (Hz)
end

%% Fixed TRx parameters
trx_profile     = 14;      % use case
refClock        = 122880;

%% Connect to board
warnState = warning('off','all');
% maxAttempts = 10;
% for k = 1:maxAttempts
%     try
%         fprintf('Attempt %d of %d...\n', k, maxAttempts);
        TRx = ADRV902x(trx_profile, centerFrequency, refClock);
%         fprintf('Connection established successfully on attempt %d\n', k);
%         return;  % Exit if successful
%     catch ME
%         fprintf('Error on attempt %d:\n%s\n', k, ME.message);
% 
%         % Small delay before retrying
%         pause(2);
%     end
% end
warning(warnState)

%% Verify connection
if ~TRx.link.IsConnected()
    error('ADRV902x_Comms:communication', ...
        'No communication with ADRV902x TRx system.');
end

pause(1);

%% Channel selection
TRx.SelTxChannels = double( ...
    adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1);

fprintf('Default TX Channels Mask: %d\n', TRx.SelTxChannels);

TRx.SelRxChannels = double( ...
    adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX2);

fprintf('Default RX Channels Mask: %d\n', TRx.SelRxChannels);

fprintf('Cuidado!!! Seleccionado el 2 pero midiendo por el 1... revisar libreria\n');

pause(1);
end
