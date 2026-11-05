function out = runReadoutLS(mode, out)
% RUNREADOUTLS Validate frozen inputs, then perform one guarded readout fit.
% Use ('preflight') to create a unique prepared folder, then ('fit',folder).
% Original files are read-only. A started real fit can never be rerun here.
    here = fileparts(mfilename('fullpath')); root = fileparts(fileparts(here));
    oldPath = path; restorePath = onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')));
    if nargin<1, mode="preflight"; end
    if string(mode)=="preflight"
        assert(isempty(dir(fullfile(here,'*','fit_started.mat'))),'A fit was already started.');
        assert(isempty(dir(fullfile(here,'*','prepared.mat'))),'Use the existing prepared run.');
        out = tempname(here); mkdir(out);
        diary(fullfile(out,'preflight.log')); dc = onCleanup(@() diary('off'));
        rngBefore = rng;
        checks.synthetic = checkReadoutSynthetic();
        assert(isequal(rngBefore,rng));
        save(fullfile(out,'synthetic.mat'),'checks','-v7.3');
        fitFolder = fullfile(root,'diagnostics','pnnn_mixed_loss', ...
            'tp390d053f_18ea_464b_8c05_db89f2b156eb');
        files = dir(fullfile(fitFolder,'**','inference.mat'));
        assert(numel(files)==1,'Expected one documented mixed inference artifact.');
        source.inference = fullfile(files.folder,files.name);
        source.experimental = fullfile(fitFolder,'experimental.mat');
        source.protocol = fullfile(fitFolder,'protocol.mat');
        A = load(source.experimental); P = load(source.protocol); M = load(source.inference);
        source.folder = A.provenance.sourceFolder;
        expected = fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
        assert(strcmpi(strrep(source.folder,'\','/'),strrep(expected,'\','/')));
        source.experiment = fullfile(source.folder,'experiment.mat');
        source.bundle = fullfile(source.folder,'models_P0310.mat');
        source.dense = fullfile(source.folder,'sweep_dense_source.mat');
        source.historical = fullfile(source.folder,'pnnn_target_0310.mat');
        source.linear = fullfile(source.folder,'linear_sweep.mat');
        source.capture = fullfile(fileparts(root),'results','experimentosSergi20261023', ...
            'experiment20261023T102742_xy.mat');
        source.oldMetrics = fullfile(files.folder,'metrics.csv');
        source.oldBins = fullfile(files.folder,'amplitude.csv');
        S = load(source.experiment); B = load(source.bundle); D = load(source.dense);
        raw = load(source.capture);
        assert(isequal(double(raw.x(:))-mean(double(raw.x(:))),S.x));
        assert(isequal(double(raw.y(:))-mean(double(raw.y(:))),S.y)); clear raw
        assert(contains(string(B.bundle.sourceFile),'20261023T102742'));
        assert(A.provenance.alpha==0.5 && isequal(A.provenance,P.provenance));
        assert(isequal(A.finalRng,P.expectedRng));
        model = M.model; st = model.normalization;
        assert(isequal(model.network.Learnables,A.result.network.Learnables));
        assert(isequal(model.network.State,A.result.network.State));
        assert(isequal(model.masks,A.result.masks,B.bundle.models{3}.masks));
        assert(isequal(st,A.provenance.normalization,D.denseSource.denseFit.normalization, ...
            B.bundle.models{3}.normalization));
        assert(isequal(model.featureConfig,B.bundle.models{3}.featureConfig));
        weights = A.provenance.weights;
        assert(max(abs(weights-[1.41775807004113 .582241929958871]))<1e-14);
        L = model.network.Learnables;
        assert(isequal(string(L.Layer),["fc1";"fc1";"fcOut";"fcOut"]));
        assert(isequal(string(L.Parameter),["Weights";"Bias";"Weights";"Bias"]));
        assert(isequal(cellfun(@nnz,model.masks),[273;12;23;2]));
        assert(isequal(sum(model.masks{3},2)+1,[12;13]));
        assert(nnz(~model.masks{1})+nnz(~model.masks{3})==736);
        for k=1:4
            v = extractdata(L.Value{k});
            assert(isa(v,'single') && all(v(~model.masks{k})==0));
            assert(nnz(v)==nnz(model.masks{k}));
        end
        id = S.split.identificationIndices; dev = S.split.evaluationIndices;
        N = numel(S.x); assert(N==491520 && numel(id)==49151 && numel(dev)==442369);
        assert(isempty(intersect(id,dev)) && isequal(sort([id(:);dev(:)]),(1:N).'));
        assert(isequal(A.provenance.options.TrainingRows,id));
        cfg = model.featureConfig;
        assert(cfg.M==13 && isequal(cfg.orders,[1 3 5 7]));
        [f,t,r] = buildPhaseNormDataset(S.x,S.y,cfg.M,cfg.orders,cfg.featMode,cfg);
        Z = (f.'-st.muX)./st.sigmaX; target = (t.'-st.muY)./st.sigmaY; r=r(:);
        clear f t D B A P
        originalPrediction = predictPNNN(model.network,Z,st,r);
        assert(isequal(originalPrediction,M.prediction),'STOP: mixed saved inference mismatch.');
        H = predict(model.network,Z,Outputs="sigmoid1");
        normalizedPrediction = predict(model.network,Z);
        assert(isequal(size(Z),[N 84]) && isequal(size(H),[N 12]));
        manual = double(H)*double(extractdata(L.Value{3})).'+double(extractdata(L.Value{4})).';
        checks.manualNormalizedRelativeL2 = norm(manual-double(normalizedPrediction),'fro')/norm(double(normalizedPrediction),'fro');
        physical = manual.*st.sigmaY+st.muY;
        manualComplex = conj(r).*complex(physical(:,1),physical(:,2));
        checks.manualComplexRelativeL2 = norm(manualComplex-double(originalPrediction))/norm(double(originalPrediction));
        assert(checks.manualNormalizedRelativeL2<1e-6 && checks.manualComplexRelativeL2<1e-6);
        checks.savedPredictionExact=true; checks.masksExact=true; checks.normalizationExact=true;
        checks.captureCenteredExact=true; checks.rngExact=isequal(rngBefore,rng);
        assert(checks.rngExact); clear M manual physical manualComplex
        provenance = struct('source',source,'weights',weights,'alpha',.5, ...
            'matlab',version,'computer',computer,'threads',maxNumCompThreads, ...
            'inputPrecision',class(Z),'activationPrecision',class(H),'targetPrecision',class(target), ...
            'rankRule','max(size(A))*eps(sigma_max(A))', ...
            'manualTolerance',1e-6,'developmentGainDb',.10,'maximumQIncreasePct',10, ...
            'protocolFile',fullfile(here,'PROTOCOL.md'),'preparedOn',char(datetime('now')));
        save(fullfile(out,'prepared.mat'),'model','Z','target','r','H','normalizedPrediction', ...
            'originalPrediction','id','dev','provenance','checks','rngBefore','-v7.3');
        disp(provenance); disp(checks);
        fprintf('PREFLIGHT COMPLETE. No real fit performed.\n%s\n',out);
    elseif string(mode)=="fit"
        assert(nargin==2 && isfile(fullfile(out,'prepared.mat')));
        assert(isempty(dir(fullfile(here,'*','fit_started.mat'))),'A real fit was already started.');
        assert(isempty(dir(fullfile(here,'*','readout_model.mat'))),'Analyze the saved model instead.');
        diary(fullfile(out,'fit.log')); dc = onCleanup(@() diary('off'));
        Q = load(fullfile(out,'prepared.mat')); rngBefore = rng;
        sourceModel = Q.model; provenance = Q.provenance;
        save(fullfile(out,'fit_started.mat'),'provenance','rngBefore');
        timer = tic;
        [network,fit] = solveMaskedReadoutLS(sourceModel.network,Q.H(Q.id,:), ...
            Q.target(Q.id,:),sourceModel.masks,provenance.weights);
        fitSeconds = toc(timer); rngAfter = rng;
        model = sourceModel; model.network = network;
        save(fullfile(out,'readout_model.mat'),'model','fit','fitSeconds','provenance','rngBefore','rngAfter','-v7.3');
        verification.rngExact = isequal(rngBefore,rngAfter); assert(verification.rngExact);
        L = network.Learnables; oldL = sourceModel.network.Learnables;
        assert(isequal(L.Value(1:2),oldL.Value(1:2)));
        assert(isequal(model.normalization,sourceModel.normalization) && isequal(model.masks,sourceModel.masks));
        assert(isequal(model.network.Connections,sourceModel.network.Connections));
        assert(isequal(model.network.State,sourceModel.network.State));
        assert(isequal(model.network.Layers(1:3),sourceModel.network.Layers(1:3)));
        assert(isequal(model.featureConfig,sourceModel.featureConfig));
        for k=1:4
            v=extractdata(L.Value{k}); before=extractdata(oldL.Value{k});
            assert(isequal(size(v),size(before)) && strcmp(class(v),class(before)) && all(isfinite(v),'all'));
            assert(all(v(~model.masks{k})==0) && nnz(v)==nnz(model.masks{k}));
        end
        assert(isequal(predict(network,Q.Z,Outputs="sigmoid1"),Q.H));
        verification.hiddenWeightsExact=true; verification.hiddenActivationsExact=true;
        verification.normalizationExact=true; verification.masksExact=true;
        verification.activeParameters=sum(cellfun(@nnz,model.masks));
        verification.prunedWeights=nnz(~model.masks{1})+nnz(~model.masks{3});
        assert(verification.activeParameters==310 && verification.prunedWeights==736);
        prediction = predictPNNN(network,Q.Z,model.normalization,Q.r);
        yn = double(predict(network,Q.Z)); ideal=zeros(size(yn)); castManual=ideal; oldManual=ideal;
        for c=1:2
            A=[double(Q.H(:,fit.outputs{c}.keep)),ones(size(Q.H,1),1)];
            ideal(:,c)=A*fit.outputs{c}.beta;
            castManual(:,c)=A*double(fit.outputs{c}.betaStored);
            oldBeta=[double(extractdata(oldL.Value{3}(c,fit.outputs{c}.keep))).'; ...
                double(extractdata(oldL.Value{4}(c)))];
            oldManual(:,c)=A*oldBeta;
        end
        verification.actualVsCastManualRelativeL2=norm(yn-castManual,'fro')/norm(yn,'fro');
        assert(verification.actualVsCastManualRelativeL2<1e-6);
        eOld=oldManual(Q.id,:)-Q.target(Q.id,:); eNew=ideal(Q.id,:)-Q.target(Q.id,:);
        dOld=double(Q.normalizedPrediction(Q.id,:))-oldManual(Q.id,:);
        dNew=yn(Q.id,:)-ideal(Q.id,:); N=numel(Q.id);
        componentBound=(2*sqrt(sum(eOld.^2,1)).*sqrt(sum(dOld.^2,1))+sum(dOld.^2,1) ...
            +2*sqrt(sum(eNew.^2,1)).*sqrt(sum(dNew.^2,1))+sum(dNew.^2,1))/N;
        beforeMSE=mean((double(Q.normalizedPrediction(Q.id,:))-Q.target(Q.id,:)).^2,1);
        afterMSE=mean((yn(Q.id,:)-Q.target(Q.id,:)).^2,1);
        assert(all(afterMSE<=beforeMSE+componentBound+100*eps));
        verification.identificationLossBefore=sum(provenance.weights.*beforeMSE)/2;
        verification.identificationLossAfter=sum(provenance.weights.*afterMSE)/2;
        verification.lossRoundingBudget=sum(provenance.weights.*componentBound)/2+100*eps;
        assert(verification.identificationLossAfter<=verification.identificationLossBefore+verification.lossRoundingBudget);
        verification.componentRoundingBounds=componentBound;
        verification.actualRelativeNE=zeros(2,1); verification.actualMaxCosine=zeros(2,1);
        for c=1:2
            A=[double(Q.H(Q.id,fit.outputs{c}.keep)),ones(N,1)]; e=yn(Q.id,c)-Q.target(Q.id,c);
            verification.actualRelativeNE(c)=norm(A.'*e)/(norm(A,'fro')*max(norm(Q.target(Q.id,c)),norm(e)));
            verification.actualMaxCosine(c)=max(abs(A.'*e)./(sqrt(sum(A.^2,1)).'*norm(e)));
        end
        st=model.normalization;
        v=ideal.*st.sigmaY+st.muY; idealPrediction=conj(Q.r).*complex(v(:,1),v(:,2));
        v=castManual.*st.sigmaY+st.muY; castPrediction=conj(Q.r).*complex(v(:,1),v(:,2));
        verification.coefficientCastPredictionRelativeL2=norm(castPrediction-idealPrediction)/norm(idealPrediction);
        verification.actualVsIdealPredictionRelativeL2=norm(double(prediction)-idealPrediction)/norm(idealPrediction);
        verification.actualVsIdealPredictionMaxAbs=max(abs(double(prediction)-idealPrediction));
        S=load(provenance.source.experiment,'y');
        verification.idealFullNMSE=nmseComplexDb(S.y,idealPrediction);
        verification.castFullNMSE=nmseComplexDb(S.y,castPrediction);
        verification.actualFullNMSE=nmseComplexDb(S.y,double(prediction));
        assert(isequal(rngBefore,rng));
        save(fullfile(out,'inference.mat'),'prediction','verification','-v7.3');
        writetable(fit.summary,fullfile(out,'ls_diagnostics.csv'));
        writetable(fit.coefficients,fullfile(out,'readout_coefficients.csv'));
        disp(fit.summary); disp(verification);
        fprintf('ONE REAL READOUT FIT COMPLETE: %.9f seconds\n%s\n',fitSeconds,out);
    else
        error('Use preflight or fit.');
    end
end
