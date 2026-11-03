function r1=canalAWGN(s,SNR)

% Canal AWGN
Psignal = 10*log10(rms(s).^2/100)+30;
n = randn(size(s))+i*randn(size(s));
P0 = 10*log10(rms(n).^2/100)+30;
n = n*10^((Psignal-SNR-P0)/20);
r1 = s+n;