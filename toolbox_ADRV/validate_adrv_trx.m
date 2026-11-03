function info = validate_adrv_trx(TRx)
%VALIDATE_ADRV_TRX Verify the existing ADRV object without reconnecting.

if isempty(TRx)
    error('ADRV:MissingTRx', ...
        ['Global TRx is empty. Run this test in the MATLAB session that ' ...
        'already owns the connected ADRV object.']);
end

info.class = class(TRx);
requiredMethods = {'transmit', 'capture'};
for ii = 1:numel(requiredMethods)
    if ~ismethod(TRx, requiredMethods{ii})
        error('ADRV:InvalidTRx', ...
            'TRx (%s) does not implement the required method %s.', ...
            info.class, requiredMethods{ii});
    end
end

try
    info.isConnected = logical(TRx.link.IsConnected());
catch ME
    error('ADRV:InvalidTRx', ...
        'Unable to query TRx.link.IsConnected() for class %s: %s', ...
        info.class, ME.message);
end
if ~info.isConnected
    error('ADRV:DisconnectedTRx', ...
        'The existing TRx object is not connected. No signal was transmitted.');
end

try
    info.txChannels = double(TRx.SelTxChannels);
    info.rxChannels = double(TRx.SelRxChannels);
catch ME
    error('ADRV:InvalidTRx', ...
        'Unable to read the selected TX/RX channels from TRx: %s', ME.message);
end
end
