function check_tx_safety(x, maxRMS_dBm, maxPEP_dBm)
% CHECK_TX_SAFETY Stops before transmitting a signal outside the safety limits.
%
%   check_tx_safety(x, maxRMS_dBm, maxPEP_dBm)
%
% Inputs:
%   x          : complex baseband signal about to be transmitted
%   maxRMS_dBm : maximum average power (dBm)
%   maxPEP_dBm : maximum peak power, average + PAPR (dBm)
%
% Raises an error, so that nothing is transmitted, if x has non-finite
% samples (NaN/Inf) or exceeds any of the power limits. Powers use the same
% 100 Ohm reference as dBm() in inline_functions (before Gin).

nBad = nnz(~isfinite(x));
if nBad > 0
    error('TX:UnsafeSignal', ...
        'Signal has %d non-finite samples (NaN/Inf). Nothing was transmitted.', nBad);
end

P_dBm   = 10*log10(mean(abs(x(:)).^2)/100) + 30;
PEP_dBm = 10*log10(max(abs(x(:)).^2)/100) + 30;

if P_dBm > maxRMS_dBm || PEP_dBm > maxPEP_dBm
    error('TX:UnsafeSignal', ...
        ['Signal exceeds the safety limits: average %.2f dBm (max %.2f), ' ...
        'peak %.2f dBm (max %.2f). Nothing was transmitted.'], ...
        P_dBm, maxRMS_dBm, PEP_dBm, maxPEP_dBm);
end

fprintf('Safety check OK: average %.2f dBm (max %.2f), peak %.2f dBm (max %.2f)\n', ...
    P_dBm, maxRMS_dBm, PEP_dBm, maxPEP_dBm);
end
