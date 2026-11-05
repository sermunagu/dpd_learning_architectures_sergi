function finishAudit()
% FINISHAUDIT Check synthetic readout derivatives and summarize saved audit.
% No inputs; writes a new summary log. No model fit or parameter update.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
assert(~isfile(fullfile(here,'summary.log')),'Summary exists.');
diary(fullfile(here,'summary.log')); cleanup=onCleanup(@() diary('off'));
A=[1 0.2 0.5;1 0.7 0.9;1 0.1 0.4;1 0.6 0.2]; w=[0.1;0.3;-0.2]; t=[.2;.4;.1;.3];
scale=1.41775807004113; h=1e-6; gradient=scale*A.'*(A*w-t)/size(A,1); fd=zeros(size(w));
for j=1:numel(w)
    wp=w; wm=w; wp(j)=wp(j)+h; wm(j)=wm(j)-h;
    fd(j)=scale*(sum((A*wp-t).^2)-sum((A*wm-t).^2))/(4*h*size(A,1));
end
assert(max(abs(fd-gradient))<1e-9); fprintf('Synthetic fixed-readout derivative max error %.12g\n',max(abs(fd-gradient)));
src=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
B=load(fullfile(src,'models_P0310.mat')); D=load(fullfile(src,'sweep_dense_source.mat'));
fprintf('Saved dense source fields: %s\n',strjoin(fieldnames(D.denseSource),', '));
fprintf('Saved dense fit fields: %s\n',strjoin(fieldnames(D.denseSource.denseFit),', '));
fprintf('Saved sparse model fields: %s\n',strjoin(fieldnames(B.bundle.models{3}),', '));
m=B.bundle.models{2}; n=numel(m.descriptors); lags=[]; cross=0; future=0; canonical=0; degrees=[];
for j=1:numel(m.selectedColumns)
    d=m.descriptors(mod(m.selectedColumns(j)-1,n)+1);
    if d.canonicalGMP
        canonical=canonical+1; degrees(end+1)=1+sum(d.envelopePowers); %#ok<AGROW>
        lags=[lags d.envelopeLags]; %#ok<AGROW>
        cross=cross+any(d.envelopeLags~=d.carrierLag); future=future+any(d.envelopeLags<0);
    end
end
fprintf('Canonical selected columns %d; cross-lag %d; future envelope %d; envelope lag range [%g,%g]; degree range [%g,%g]\n',canonical,cross,future,min(lags),max(lags),min(degrees),max(degrees));
d=fullfile(here,'tp7d131b74_614e_4611_8771_7807054f30c4');
for file=["amplitude","correction_regions","temporal"]
    T=readtable(fullfile(d,file+'.csv')); n=height(T)/2; gap=T.NMSE(1:n)-T.NMSE(n+1:end);
    fprintf('%s PN-IQ advantage dB range %.9f to %.9f; first %.9f last %.9f\n',file,min(gap),max(gap),gap(1),gap(end));
end
T=readtable(fullfile(d,'spectral_bands.csv'));
fprintf('Spectral error power advantage dB: '); fprintf('%.9f ',10*log10(T.ErrorPower(1:3)./T.ErrorPower(4:6))); fprintf('\n');
T=readtable(fullfile(d,'autocorrelation.csv')); fprintf('Residual autocorrelation magnitudes at lag 1: %.9f %.9f; lag 5: %.9f %.9f\n',T.Magnitude(2),T.Magnitude(67),T.Magnitude(6),T.Magnitude(71));
T=readtable(fullfile(d,'metrics.csv')); fprintf('Full I and Q shares of MSE advantage: %.9f %.9f\n', ...
    (T.MSEI(3)-T.MSEI(6))/(T.MSE(3)-T.MSE(6)),(T.MSEQ(3)-T.MSEQ(6))/(T.MSE(3)-T.MSE(6)));
ff=dir(fullfile(here,'*.m')); for k=1:numel(ff), fprintf('CHECKCODE %s\n',ff(k).name); disp(checkcode(fullfile(here,ff(k).name),'-id')); end
end
