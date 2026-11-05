function m=errorMetrics(x,y,p)
% ERRORMETRICS Common physical metrics in the input-rotated coordinate frame.
% Inputs: equal-length finite column vectors. Output: one row of metrics.
assert(iscolumn(x) && iscolumn(y) && iscolumn(p) && isequal(size(x),size(y),size(p)));
assert(all(isfinite(x)) && all(isfinite(y)) && all(isfinite(p)));
r=ones(size(x)); nz=abs(x)>0; r(nz)=conj(x(nz))./abs(x(nz));
e=p-y; er=r.*e; mi=mean(real(er).^2); mq=mean(imag(er).^2);
total=mean(abs(e).^2); ref=mean(abs(y).^2);
assert(abs(mi+mq-total)<1e-12*max(total,eps));
m=table(numel(x),10*log10(total/ref),mi,mq,total,mean(abs(e)), ...
    sqrt(mean(abs(p).^2)),10*log10(max(abs(p).^2)/mean(abs(p).^2)),sqrt(total/ref), ...
    mean(real(er)),mean(imag(er)), ...
    'VariableNames',{'N','NMSE','MSEI','MSEQ','MSE','MAE','RMS','PAPR','RelativeL2','BiasI','BiasQ'});
end
