% inline functions
PAPR = @(x) 20*log10(max(abs(x))/rms(x)); 
maxdBm = @(x) dBm(x) + PAPR(x);
dBminst = @(x) 10*log10(abs(x).^2/100)+30;
dBm = @(x) 10*log10(rms(x).^2/100)+30;
scale_dBm = @(x,P) x*10^((P-dBm(x))/20);