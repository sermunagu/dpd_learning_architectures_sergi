function analyzeSession(directory)
% ANALYZESESSION Summarize repeated fits and plot chronological epoch timings.
% Input: completed diagnostic directory. Outputs: CSV and PNG summaries there.
    S=readtable(fullfile(directory,'summary.csv'),'TextType','string');
    E=readtable(fullfile(directory,'epochs.csv'),'TextType','string');
    assert(height(S)==12,'Session has not finished.');
    byBudget=table();
    for P=[100 310 400]
        original=S.TotalSeconds(S.P==P & S.Variant=="original");
        accelerated=S.TotalSeconds(S.P==P & S.Variant=="accelerated");
        byBudget=[byBudget;table(P,mean(original),mean(accelerated),min(original),max(original), ...
            min(accelerated),max(accelerated),mean(original)/mean(accelerated), ...
            100*(1-mean(accelerated)/mean(original)), ...
            'VariableNames',{'P','OriginalMean','AcceleratedMean','OriginalMin','OriginalMax', ...
            'AcceleratedMin','AcceleratedMax','Speedup','PercentSaved'})]; %#ok<AGROW>
    end
    writetable(byBudget,fullfile(directory,'by_budget.csv')); disp(byBudget);
    fprintf('Balanced aggregate: original %.4fs; accelerated %.4fs; speedup %.4fx; saving %.3f%%\n', ...
        mean(S.TotalSeconds(S.Variant=="original")),mean(S.TotalSeconds(S.Variant=="accelerated")), ...
        sum(S.TotalSeconds(S.Variant=="original"))/sum(S.TotalSeconds(S.Variant=="accelerated")), ...
        100*(1-sum(S.TotalSeconds(S.Variant=="accelerated"))/sum(S.TotalSeconds(S.Variant=="original"))));
    for block=1:4
        B=S(S.Block==block,:);
        fprintf('Block %d %s mean %.4f s; min/max epoch late/early %.4f / %.4f\n', ...
            block,B.Variant(1),mean(B.TotalSeconds),min(B.LateEarlyRatio),max(B.LateEarlyRatio));
    end
    disp(S(:,{'Sequence','Variant','P','TotalSeconds','EarlyMedian','LateMedian','LateEarlyRatio','HitRate','Occupancy'}));
    fprintf('Exact flags: weights %d masks %d predictions %d RNG %d network state %d\n', ...
        all(S.WeightsEqual),all(S.MasksEqual),all(S.PredictionEqual),all(S.RNGEqual),all(S.StateEqual));
    fprintf('Max deltas: weights %.17g predictions %.17g NMSE %.17g\n',max(S.MaxWeightDifference),max(S.MaxPredictionDifference),max(abs(S.NMSEDelta)));
    fprintf('MATLAB memory before first/after last: %.1f / %.1f MiB\n',S.MemoryBefore(1)/2^20,S.MemoryAfter(end)/2^20);
    for variant=["original","accelerated"]
        for P=[100 310 400]
            runs=S.Sequence(S.Variant==variant & S.P==P);
            A=load(fullfile(directory,sprintf('run_%02d.mat',runs(1))));
            B=load(fullfile(directory,sprintf('run_%02d.mat',runs(2))));
            fprintf('Repeat identity %s P%d weights/masks/RNG %d/%d/%d\n',variant,P, ...
                isequal(A.learnables,B.learnables),isequal(A.masks,B.masks),isequal(A.finalRng,B.finalRng));
        end
    end
    fprintf('CPU/wall effective utilization per fit: '); fprintf('%.2f ',S.CPUSeconds./S.TotalSeconds); fprintf('\n');
    f=figure('Visible','off','Position',[50 50 1200 750]);
    tiledlayout(2,1);
    nexttile; hold on;
    colors=[0.15 0.35 0.7; 0.85 0.35 0.1];
    for j=1:height(S)
        color=colors(1+double(S.Variant(j)=="accelerated"),:);
        bar(j,S.TotalSeconds(j),'FaceColor',color);
    end
    xticks(1:12); xticklabels(compose('%d: P%d',S.Sequence,S.P));
    ylabel('Full 164-epoch fit (s)'); title('Blue: original; orange: dlaccelerate. Blocks O-forward / A-reverse / A-forward / O-reverse'); grid on;
    nexttile; hold on;
    for j=1:height(S)
        local=E(E.Sequence==j,:); time=S.StartSeconds(j)+cumsum(local.WallSeconds);
        color=colors(1+double(S.Variant(j)=="accelerated"),:);
        plot(time/60,local.WallSeconds,'.','Color',color,'MarkerSize',3);
        plot(time/60,movmedian(local.WallSeconds,20),'Color',color,'LineWidth',1.5);
    end
    xlabel('Elapsed session minutes (timed blocks and verification gaps)'); ylabel('Epoch wall time (s)'); grid on;
    title('Epoch observations and 20-epoch moving medians; no smoothing across fit boundaries');
    exportgraphics(f,fullfile(directory,'session_timing.png'),'Resolution',150); close(f);
end
