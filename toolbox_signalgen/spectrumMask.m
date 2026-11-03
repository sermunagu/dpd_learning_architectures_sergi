function y = spectrumMask(u, mask)
% SPECTRUMMASK ideally shapes the spectrum according to the input mask.
% Last Modified: Kevin Chuang, 2022-04-07
% kevin.chuang@analog.com

if nargin < 2
    mask = [-1 1 1];
end

fu = fftshift(fft(u));
N = numel(u);

for i=1:size(mask,1)
    a = round(interp1(linspace(-1,1,N),1:N, mask(i,1:2)));
    fu(a(1):a(2)) = fu(a(1):a(2))*mask(i,3);
end
y = (ifft(fftshift(fu)));
