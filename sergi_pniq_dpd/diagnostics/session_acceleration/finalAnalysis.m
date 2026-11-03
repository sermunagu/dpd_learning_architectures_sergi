here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
out=fullfile(here,'tp705818e5_a36d_45e4_ae24_88e83faabad1');
addpath(here,genpath(fullfile(root,'toolbox'))); analyzeSession(out);
source=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
S=load(fullfile(source,'experiment.mat')); D=load(fullfile(source,'sweep_dense_source.mat'));
[f,~,rot]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
stats=D.denseSource.denseFit.normalization; f=(f.'-stats.muX)./stats.sigmaX;
T=readtable(fullfile(out,'summary.csv'),'TextType','string'); numerical=table();
for P=[100 310 400]
    ref=load(fullfile(source,sprintf('pnnn_target_%04d.mat',P))); net=ref.point.model.network;
    j=T.Sequence(T.P==P & T.Variant=="accelerated"); A=load(fullfile(out,sprintf('run_%02d.mat',j(1))));
    b=[]; a=[]; zerosOK=true;
    for k=1:height(A.learnables)
        v=double(extractdata(A.learnables.Value{k})); r=double(extractdata(net.Learnables.Value{k}));
        a=[a;v(:)]; b=[b;r(:)]; zerosOK=zerosOK && all(v(~A.masks{k})==0);
    end
    net.Learnables=A.learnables; pred=predictPNNN(net,f,stats,rot(:)); target=ref.point.fullSignalPrediction;
    wAbs=max(abs(a-b)); wRelInf=wAbs/max(abs(b)); wRelL2=norm(a-b)/norm(b);
    predAbs=max(abs(double(pred)-double(target))); predRelInf=predAbs/max(abs(double(target))); predRelL2=norm(double(pred)-double(target))/norm(double(target));
    nmseOld=nmseComplexDb(S.y,target); nmseNew=nmseComplexDb(S.y,pred);
    % Scale-aware candidates for acceptance, not previously agreed requirements.
    weightTolerance=all(abs(a-b)<=1e-7+1e-5*abs(b));
    predictionTolerance=all(abs(double(pred)-double(target))<=1e-7+1e-5*abs(double(target)));
    row=table(P,wAbs,wRelInf,wRelL2,predAbs,predRelInf,predRelL2,nmseOld,nmseNew,zerosOK,weightTolerance,predictionTolerance);
    numerical=[numerical;row];
end
writetable(numerical,fullfile(out,'numerical_equivalence.csv')); disp(numerical);