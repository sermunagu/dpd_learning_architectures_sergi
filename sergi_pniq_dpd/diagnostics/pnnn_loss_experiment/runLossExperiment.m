function runLossExperiment()
% RUNLOSSEXPERIMENT Validate and run exactly one new physical-loss P310 fit.
% No inputs. Unique outputs here; source checkpoints are read-only.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; c=onCleanup(@() path(old)); addpath(here,genpath(fullfile(root,'toolbox')));
assert(isempty(dir(fullfile(here,'*','experimental.mat'))),'A fit already exists: use analyzeLossExperiment on it.');
assert(isempty(dir(fullfile(here,'*','training_started.mat'))),'A real fit was already started; do not repeat it.');
out=tempname(here); mkdir(out); diary(fullfile(out,'execution.log')); dc=onCleanup(@() diary('off'));
folder=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
S=load(fullfile(folder,'experiment.mat')); D=load(fullfile(folder,'sweep_dense_source.mat'));
B=load(fullfile(folder,'pnnn_target_0310.mat')); dense=D.denseSource; st=dense.denseFit.normalization;
assert(contains(S.provenance.sourceFile,'experiment20261023T102742_xy.mat'));
raw=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_xy.mat'));
assert(isequal(double(raw.x(:))-mean(double(raw.x(:))),S.x));
assert(isequal(double(raw.y(:))-mean(double(raw.y(:))),S.y));
[f,t,r]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
f=f.'; t=t.'; r=r(:); id=S.split.identificationIndices;
assert(size(f,2)==84 && dense.fineTuneEpochs==164);
assert(isequal(st,B.point.model.normalization));
sx=std(f(id,:),0,1); sx(sx==0)=1;
assert(isequal(mean(f(id,:),1),st.muX) && isequal(sx,st.sigmaX));
assert(isequal(mean(t(id,:),1),st.muY) && isequal(std(t(id,:),0,1),st.sigmaY));
baseline=predictPNNN(B.point.model.network,(f-st.muX)./st.sigmaX,st,r);
assert(isequal(baseline,B.point.fullSignalPrediction));
assert(abs(nmseComplexDb(S.y,baseline)+35.1288921476265)<1e-10);
w=2*st.sigmaY.^2/sum(st.sigmaY.^2); assert(abs(mean(w)-1)<1e-14);
config=dense.runtimeConfig; config.training.verbose=false; config.pruning.useAcceleration=false;
options=struct('Mode',"fixed-epochs",'TrainingRows',id,'ValidationRows',[], ...
    'TargetActiveParameters',310,'NNSeed',S.cfg.pnnn.nnSeed,'FineTuneEpochs',0,'Config',config,'LossWeights',w);
initial=pruneAndFineTunePNNN(dense.denseFit,f,t,options); % Zero updates, mask reconstruction only.
assert(isequal(initial.masks,B.point.model.masks));
assert(initial.counts.activeWeightParams==296 && initial.counts.activeBiasParams==14);
% Synthetic loss/gradient/phase checks, not a real training repeat.
rng(701,'twister'); yy=randn(2,7); tt=randn(2,7);
[lv,g]=dlfeval(@lossGradient,dlarray(yy,'CB'),dlarray(tt,'CB'),w);
expectedGrad=w(:).*(yy-tt)/7;
assert(max(abs(extractdata(g)-expectedGrad),[],'all')<1e-12);
physical=mean(sum((st.sigmaY(:).*(yy-tt)).^2,1))/sum(st.sigmaY.^2);
assert(abs(extractdata(lv)-physical)<1e-12);
[lh,gh]=dlfeval(@lossGradient,dlarray(yy,'CB'),dlarray(tt,'CB'),[1 1]);
assert(abs(extractdata(lh)-mean((yy-tt).^2,'all'))<1e-12);
assert(max(abs(extractdata(gh)-(yy-tt)/7),[],'all')<1e-12);
rot=exp(1i*(1:7).'); z=yy.'.*st.sigmaY+st.muY;
restored=conj(rot).*complex(z(:,1),z(:,2));
assert(norm(rot.*restored-complex(z(:,1),z(:,2)))<1e-12);
sf=randn(32,84).*st.sigmaX+st.muX; sy=randn(32,2).*st.sigmaY+st.muY;
synthetic=options; synthetic.TrainingRows=(1:32).'; synthetic.FineTuneEpochs=1; synthetic.LossWeights=[1 1];
a=pruneAndFineTunePNNN(dense.denseFit,sf,sy,synthetic); arng=rng;
b=lossPrunePNNN(dense.denseFit,sf,sy,synthetic);
assert(isequal(a.network.Learnables,b.network.Learnables) && isequal(arng,rng));
assert(isequal(a.masks,b.masks)); synthetic.LossWeights=w;
b=lossPrunePNNN(dense.denseFit,sf,sy,synthetic);
for k=1:height(b.network.Learnables)
    v=extractdata(b.network.Learnables.Value{k}); assert(all(v(~b.masks{k})==0));
end
% Replay the exact historical permutations and check against the saved original RNG.
options.FineTuneEpochs=164; rng(options.NNSeed+config.pruning.fineTuneSeedOffset,'twister');
orders=zeros(numel(id),164,'uint32');
for epoch=1:164, orders(:,epoch)=uint32(randperm(numel(id))).'; end
expectedRng=rng;
oldRun=load(fullfile(root,'diagnostics','session_acceleration','tp705818e5_a36d_45e4_ae24_88e83faabad1','run_11.mat'),'finalRng');
assert(isequal(expectedRng,oldRun.finalRng));
provenance=struct('sourceFolder',folder,'capture',S.provenance.sourceFile,'matlab',version, ...
    'computer',computer,'threads',maxNumCompThreads,'options',options,'weights',w,'normalization',st, ...
    'masks',{initial.masks},'sourceConfig',S.cfg,'started',char(datetime('now')));
save(fullfile(out,'protocol.mat'),'provenance','initial','orders','expectedRng','-v7.3'); clear orders
fprintf('PRECHECKS PASS; weights %.15g %.15g; baseline %.12f dB\n',w,nmseComplexDb(S.y,baseline));
fprintf('START ONLY REAL FIT: P310, 164 epochs, no acceleration. Output %s\n',out);
save(fullfile(out,'training_started.mat'),'options');
tic; result=lossPrunePNNN(dense.denseFit,f,t,options); seconds=toc; finalRng=rng;
save(fullfile(out,'experimental.mat'),'result','seconds','finalRng','provenance','-v7.3');
assert(isequal(result.masks,initial.masks) && isequal(finalRng,expectedRng));
fprintf('FIT SAVED %.3f seconds; exact masks and RNG.\n',seconds);
clear f t raw dense D result baseline
analyzeLossExperiment(out);
end

function [loss,gradient]=lossGradient(y,t,w)
% Differentiate the same scalar loss used inside the experimental model.
loss=weightedLoss(y,t,w); gradient=dlgradient(loss,y);
end
