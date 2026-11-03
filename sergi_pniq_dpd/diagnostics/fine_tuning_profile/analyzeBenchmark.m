function analyzeBenchmark(directory)
% ANALYZEBENCHMARK Summarize completed diagnostic timings and call-tree costs.
% Input: diagnostic run directory. Output: CSV summaries in the same directory.
    S=readtable(fullfile(directory,'summary.csv'));
    names={'MinibatchSeconds','DlfevalSeconds','GradientMaskSeconds','AdamSeconds','WeightMaskSeconds','OtherSeconds'};
    totals=sum(S{:,names},1); fractions=totals/sum(S.TotalSeconds);
    stages=table(string(names).',totals.',100*fractions.', ...
        'VariableNames',{'Stage','SecondsThreeBudgets','PercentTotal'});
    writetable(stages,fullfile(directory,'stage_summary.csv')); disp(S); disp(stages);
    B=load(fullfile(directory,'baseline_P310.mat'));
    fprintf('Uninstrumented P310 %.3f s; timed %.3f s; apparent overhead %.2f%%\n', ...
        B.baselineSeconds,S.TotalSeconds(S.P==310),100*(S.TotalSeconds(S.P==310)/B.baselineSeconds-1));
    for P=S.P.'
        T=load(fullfile(directory,sprintf('timing_P%d.mat',P)));
        d=T.diagnostic; n=size(d.steps,1)/numel(d.epochs);
        fprintf('P%d: %d steps; first epoch %.3fs; steady epoch median %.3fs; p10 %.3fs; p90 %.3fs\n', ...
            P,size(d.steps,1),d.epochs(1),median(d.epochs(2:end)), ...
            prctile(d.epochs(2:end),10),prctile(d.epochs(2:end),90));
        fprintf('Steady per-step median milliseconds: '); fprintf('%.4f ',1000*median(d.steps(n+1:end,:),1)); fprintf('\n');
    end
    F=load(fullfile(directory,'call_tree_one_epoch.mat')); f=F.profileInfo.FunctionTable;
    exclusive=zeros(numel(f),1);
    for i=1:numel(f), exclusive(i)=f(i).TotalTime-sum([f(i).Children.TotalTime]); end
    functions=table(string({f.FunctionName}).',[f.NumCalls].',[f.TotalTime].',exclusive, ...
        'VariableNames',{'Function','Calls','InclusiveSeconds','SelfSeconds'});
    functions=sortrows(functions,'SelfSeconds','descend');
    writetable(functions,fullfile(directory,'call_tree_functions.csv')); disp(functions(1:min(25,height(functions)),:));
end
