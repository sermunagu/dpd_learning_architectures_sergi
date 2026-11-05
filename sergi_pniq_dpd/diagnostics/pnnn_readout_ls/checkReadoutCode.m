function checkReadoutCode()
% CHECKREADOUTCODE Save static-analysis results for this isolated experiment.
% No inputs; writes static_checks.log once. Does not execute any experiment.
    here=fileparts(mfilename('fullpath'));
    assert(~isfile(fullfile(here,'static_checks.log')),'Static log already exists.');
    diary(fullfile(here,'static_checks.log')); dc=onCleanup(@() diary('off'));
    files=dir(fullfile(here,'*.m'));
    for k=1:numel(files)
        fprintf('CHECKCODE %s\n',files(k).name);
        issues=checkcode(fullfile(here,files(k).name),'-id');
        for j=1:numel(issues)
            fprintf('Line %d: %s\n',issues(j).line,issues(j).message);
        end
        if isempty(issues), fprintf('No messages.\n'); end
    end
end
