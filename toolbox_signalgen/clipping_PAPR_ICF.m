function y = clipping_PAPR_ICF(x, PAPRd, mask, Niter)

% Iterative Clipping and Filtering for OFDM signals
%
% x      : input signal
% PAPRd  : target PAPR (dB)
% ovs    : oversampling factor
% Niter  : number of ICF iterations

if nargin < 4
    Niter = 5;
end

if nargin < 3
    ovs = 4;
end

x = x(:);
N = length(x);

% Target amplitude
PAPRlin = 10^(PAPRd/10);
Px = mean(abs(x).^2);
A = sqrt(PAPRlin*Px);

y = x;

for k = 1:Niter

    %% --- Clipping ---
    idx = abs(y) > A;
    y(idx) = A .* exp(1j*angle(y(idx)));

    %% --- Frequency domain filtering ---
%     Y = fftshift(fft(y));
% 
%     % Ideal bandlimiting
%     BW = floor(N/(2*ovs));
%     center = floor(N/2)+1;
% 
%     mask = zeros(N,1);
%     mask(center-BW:center+BW) = 1;
% 
%     Y = Y .* mask;
% 
%     y = ifft(ifftshift(Y));
y = spectrumMask(y, mask);

end

end