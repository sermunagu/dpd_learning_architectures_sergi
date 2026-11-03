function checkTraceReuse()
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here)); addpath(genpath(fullfile(root,'toolbox')));
out=fullfile(here,'tp705818e5_a36d_45e4_ae24_88e83faabad1');
source=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
S=load(fullfile(source,'experiment.mat')); M=load(fullfile(source,'pnnn_target_0310.mat')); net=M.point.model.network;
[f,t]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
st=M.point.model.normalization; f=(f.'-st.muX)./st.sigmaX; t=(t.'-st.muY)./st.sigmaY;
changed=net; L=changed.Learnables; L.Value{1}=L.Value{1}+single(.01); changed.Learnables=L;
fun=dlaccelerate(@lossFunction); clearCache(fun); checks=table();
for k=1:6
    n=1024; first=1; active=net; if k==2, first=1025; end
    if ismember(k,[3 4]), active=changed; end
    if k==5, n=1023; end
    x=dlarray(f(first:first+n-1,:).','CB'); y=dlarray(t(first:first+n-1,:).','CB'); if k==4, y=y+0.1; end
    [a,g]=dlfeval(@lossFunction,active,x,y); [b,h]=dlfeval(fun,active,x,y);
    lossAbs=abs(double(extractdata(a))-double(extractdata(b))); gv=[]; hv=[];
    for j=1:height(g), v=double(extractdata(g.Value{j})); w=double(extractdata(h.Value{j})); gv=[gv;v(:)]; hv=[hv;w(:)]; end
    gradientAbs=max(abs(gv-hv)); gradientRelative=norm(gv-hv)/max(norm(gv),eps);
    pass=lossAbs<=1e-6+1e-5*abs(double(extractdata(a))) && all(abs(gv-hv)<=1e-6+1e-5*abs(gv));
    referenceLoss=double(extractdata(a)); acceleratedLoss=double(extractdata(b));
    checks=[checks;table(k,referenceLoss,acceleratedLoss,lossAbs,gradientAbs,gradientRelative,pass)];
end
assert(all(checks.pass)); assert(checks.referenceLoss(1)~=checks.referenceLoss(3));
disp(checks); fprintf('Cache hit rate %.4f%% occupancy %.4f%%\n',fun.HitRate,fun.Occupancy);
writetable(checks,fullfile(out,'trace_reuse_checks.csv'));
end
function [loss,gradients]=lossFunction(network,x,t)
y=forward(network,x); loss=mean((y-t).^2,'all'); gradients=dlgradient(loss,network.Learnables);
end