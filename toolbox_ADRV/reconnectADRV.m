function reconnectADRV(centerFrequency)
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
    TRx = ADRV902x.reconnect(centerFrequency);
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
