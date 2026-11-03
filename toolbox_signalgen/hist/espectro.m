function  [Pxx,fvec] = espectro(x, fs,figuren)
%PSD estimate

wlen = 8e3;
olap = 5e3;
nfft = 8e3;
win = kaiser(wlen,50);
Pxx = pwelch(x, win, olap, nfft); %Welch periodogram estimate using Hanning window
Pxx = fftshift(Pxx);
N = length(Pxx);
fvec = (-fs/2:fs/N:(N-1)/N*fs/2);

Pxx = 10*log10(Pxx);
fvec = fvec/1e6;

figure(figuren);
hold on
plot(fvec,Pxx);
xlabel('MHz'); title('PSD (dB/Hz)');
end