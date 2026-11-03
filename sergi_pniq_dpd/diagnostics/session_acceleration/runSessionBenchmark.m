function runSessionBenchmark()
% RUNSESSIONBENCHMARK Compare original/accelerated fixed-epoch fits in one session.
% No inputs. Writes unique diagnostic outputs only; production is read-only.
    here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
    oldPath=path; cleanup=onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')));
    directory=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
    out=tempname(here); mkdir(out); fprintf('Output: %s\n',out);
    S=load(fullfile(directory,'experiment.mat')); D=load(fullfile(directory,'sweep_dense_source.mat'));
    dense=D.denseSource; dense.runtimeConfig.training.verbose=S.cfg.training.verbose;
    assert(~isa(extractdata(dense.denseFit.network.Learnables.Value{1}),'gpuArray'),'CPU benchmark required.');
    [features,targets,rotation]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
    features=features.'; targets=targets.'; rotation=rotation(:);
    stats=dense.denseFit.normalization;
    normalized=(features-stats.muX)./stats.sigmaX;
    options=struct('Mode',"fixed-epochs",'TrainingRows',S.split.identificationIndices,'ValidationRows',[], ...
        'NNSeed',S.cfg.pnnn.nnSeed,'FineTuneEpochs',dense.fineTuneEpochs,'Config',dense.runtimeConfig);
    % ABBA blocks balance method order; both directions for both methods.
    budgets=[100 310 400;400 310 100;100 310 400;400 310 100];
    accelerated=[false true true false];
    environment=struct('version',version,'computer',computer,'threads',maxNumCompThreads, ...
        'processor',getenv('PROCESSOR_IDENTIFIER'),'directory',directory,'options',options, ...
        'budgets',budgets,'accelerated',accelerated,'started',char(datetime('now')));
    save(fullfile(out,'environment.mat'),'environment');
    options.TargetActiveParameters=310; options.FineTuneEpochs=1;
    fprintf('Warmup and one-epoch equality control against unmodified production...\n');
    production=pruneAndFineTunePNNN(dense.denseFit,features,targets,options); productionRng=rng;
    for flag=[false true]
        options.UseAcceleration=flag;
        warm=sessionPrunePNNN(dense.denseFit,features,targets,options);
        warmWeights=isequal(production.network.Learnables,warm.network.Learnables);
        warmMasks=isequal(production.masks,warm.masks); warmRNG=isequal(productionRng,rng);
        fprintf('Warmup accelerated=%d: equal weights/masks/RNG=%d/%d/%d\n',flag,warmWeights,warmMasks,warmRNG);
        if ~flag, assert(warmWeights && warmMasks && warmRNG,'Baseline instrumentation differs.'); end
        save(fullfile(out,sprintf('warmup_%d.mat',flag)),'warmWeights','warmMasks','warmRNG');
    end
    clear warm production
    options.FineTuneEpochs=dense.fineTuneEpochs;
    references=cell(1,3); referenceRng=cell(1,3); Ps=[100 310 400];
    for i=1:3, references{i}=load(fullfile(directory,sprintf('pnnn_target_%04d.mat',Ps(i))),'point'); end
    summary=table(); epochTable=table(); sessionTimer=tic; sequence=0;
    for block=1:4
        for position=1:3
            sequence=sequence+1; P=budgets(block,position); index=find(Ps==P);
            options.TargetActiveParameters=P; options.UseAcceleration=accelerated(block);
            variant="original"; if options.UseAcceleration, variant="accelerated"; end
            fprintf('START %02d/12 block %d position %d: %s P%d, %d epochs\n',sequence,block,position,variant,P,options.FineTuneEpochs);
            startSeconds=toc(sessionTimer); mem=memory; memoryBefore=mem.MemUsedMATLAB;
            cpuStart=cputime; wall=tic;
            result=sessionPrunePNNN(dense.denseFit,features,targets,options);
            totalSeconds=toc(wall); cpuSeconds=cputime-cpuStart; finalRng=rng;
            mem=memory; memoryAfter=mem.MemUsedMATLAB;
            if isempty(referenceRng{index}), referenceRng{index}=finalRng; end
            point=references{index}.point;
            weightsEqual=isequal(result.network.Learnables,point.model.network.Learnables);
            masksEqual=isequal(result.masks,point.model.masks); rngEqual=isequal(finalRng,referenceRng{index});
            stateEqual=isequal(result.network.State,point.model.network.State);
            maxWeightDifference=0;
            for k=1:height(result.network.Learnables)
                a=double(extractdata(result.network.Learnables.Value{k})); b=double(extractdata(point.model.network.Learnables.Value{k}));
                maxWeightDifference=max(maxWeightDifference,max(abs(a(:)-b(:))));
            end
            prediction=predictPNNN(result.network,normalized,stats,rotation);
            predictionEqual=isequal(prediction,point.fullSignalPrediction);
            maxPredictionDifference=max(abs(double(prediction)-double(point.fullSignalPrediction)));
            nmse=nmseComplexDb(S.y,prediction); savedNMSE=nmseComplexDb(S.y,point.fullSignalPrediction); nmseDelta=nmse-savedNMSE;
            d=result.diagnostic;
            earlyMedian=median(d.epochWall(2:41)); lateMedian=median(d.epochWall(end-39:end)); lateEarlyRatio=lateMedian/earlyMedian;
            row=table(sequence,block,position,variant,P,startSeconds,totalSeconds,cpuSeconds,memoryBefore,memoryAfter, ...
                earlyMedian,lateMedian,lateEarlyRatio,weightsEqual,masksEqual,rngEqual,stateEqual, ...
                predictionEqual,maxWeightDifference,maxPredictionDifference,nmseDelta,d.hitRate,d.occupancy, ...
                'VariableNames',{'Sequence','Block','Position','Variant','P','StartSeconds','TotalSeconds','CPUSeconds', ...
                'MemoryBefore','MemoryAfter','EarlyMedian','LateMedian','LateEarlyRatio','WeightsEqual','MasksEqual', ...
                'RNGEqual','StateEqual','PredictionEqual','MaxWeightDifference','MaxPredictionDifference','NMSEDelta','HitRate','Occupancy'});
            summary=[summary;row]; %#ok<AGROW>
            E=numel(d.epochWall);
            epochTable=[epochTable;table(repmat(sequence,E,1),repmat(variant,E,1),repmat(P,E,1),(1:E).', ...
                d.epochWall,d.epochCPU,'VariableNames',{'Sequence','Variant','P','Epoch','WallSeconds','CPUSeconds'})]; %#ok<AGROW>
            writetable(summary,fullfile(out,'summary.csv')); writetable(epochTable,fullfile(out,'epochs.csv'));
            learnables=result.network.Learnables; masks=result.masks;
            save(fullfile(out,sprintf('run_%02d.mat',sequence)),'d','row','finalRng','learnables','masks');
            fprintf('DONE %02d: %.3fs; late/early %.3f; equal weights/masks/prediction/RNG %d/%d/%d/%d; hit rate %.3f%%\n', ...
                sequence,totalSeconds,lateEarlyRatio,weightsEqual,masksEqual,predictionEqual,rngEqual,d.hitRate);
            clear result prediction learnables masks
        end
    end
    fprintf('SESSION COMPLETE %.1fs: %s\n',toc(sessionTimer),out);
end
