% MAIN_2_TESTEXPERIMENT  Template for offline DPD modeling (step 2 of 3).
%
% Step 1 (main_1_learnDPD) finds the PA input that linearizes the PA and
% saves it in results/experiment<filenamedate>_xy.mat:
%   x : original signal u (DPD input)
%   y : PA input found in the last iteration with DPD (DPD target)
%
% This script loads that file, models the DPD (u -> xdpd) in the section
% marked "fill in" (with a GMP least-squares example and room for more
% models) and saves the DPD signals in the format read by step 3
% (main_3_testDPD):
%   results/experiment<filenamedate>_xy_execution_<comparison_type>.mat
%     comparison_type     : name of the group of signals
%     dpd(k).modeltype    : name of the case (shown by main_3_testDPD)
%     dpd(k).yvalmod      : DPD signal to measure, same length as u
%     dpd(k).n_regressors : (optional) only needed to filter with
%                           dpd_n_regressors in main_3_testDPD
%
% In the same MATLAB session, main_1_learnDPD leaves filenamedate
% in the workspace. In a new session, set it explicitly to select an older
% experiment, or let this script select the newest complete experiment.
%
% Optional setting before running this script:
%   comparison_type = 'my_group';  % name of the output group ['custom']

projectRoot = fileparts(mfilename('fullpath'));
cd(projectRoot);
addpath(fullfile(projectRoot, 'toolbox'));
addpath(fullfile(projectRoot, 'confset'));

%% Experiment selection
if ~exist('filenamedate', 'var') || isempty(filenamedate)
    xyFiles = dir(fullfile('results', 'experiment*_xy.mat'));
    complete = false(size(xyFiles));
    for fileIdx = 1:numel(xyFiles)
        experimentFile = strrep(xyFiles(fileIdx).name, '_xy.mat', '.mat');
        complete(fileIdx) = isfile(fullfile('results', experimentFile));
    end
    xyFiles = xyFiles(complete);
    if isempty(xyFiles)
        error('DPD:MissingExperiment', ...
            'No complete experiment found in results/. Run main_1_learnDPD first.');
    end
    [~, newest] = max([xyFiles.datenum]);
    filenamedate = extractBetween(xyFiles(newest).name, 'experiment', '_xy.mat');
    filenamedate = char(filenamedate);
end

filenamedate = char(string(filenamedate));
xyPath = fullfile('results', ['experiment' filenamedate '_xy.mat']);
experimentPath = fullfile('results', ['experiment' filenamedate '.mat']);
if ~isfile(xyPath) || ~isfile(experimentPath)
    error('DPD:MissingExperiment', ...
        'Experiment files for %s are incomplete. Expected %s and %s.', ...
        filenamedate, xyPath, experimentPath);
end

%% Output of step 1
% Loaded into a struct so that the session variables are not overwritten
xy = load(xyPath, 'x', 'y');
u    = xy.x(:);   % DPD input: original signal
xdpd = xy.y(:);   % DPD target: PA input found in step 1
fprintf('Experiment %s: %d samples loaded from %s\n', filenamedate, numel(u), xyPath);

dpd = struct('modeltype', {}, 'yvalmod', {});

%% ===================== DPD MODELING (fill in) ======================
% Train the DPD models with (u -> xdpd) and add one entry per signal to
% measure in step 3:
%   dpd(end+1).modeltype = 'My model';
%   dpd(end).yvalmod     = <DPD output for the whole signal u>;

% Example: GMP fitted by least squares to the signal found in step 1,
% identified with the window around the peak of |xdpd| (sel_indices) and
% applied to the whole signal (normalized columns, as in the DLA update of
% main_1_learnDPD)
perc_id = 0.1;                          % Fraction of the signal used for identification
model_configuration_B
U = model_gmp_generate_X(u, u, dpd_model);
ind = sel_indices(u, xdpd, perc_id);
normU = vecnorm(U(ind,:));
Un = U(ind,:)*diag(normU.^-1);
h = diag(normU.^-1)*(inv(Un'*Un)*Un')*xdpd(ind);
dpd(end+1).modeltype = 'GMP LS (ILC signal)';
dpd(end).yvalmod     = U*h;
fprintf('%s: NMSE = %.2f dB (identification, %d samples), %.2f dB (whole signal)\n', ...
    dpd(end).modeltype, 20*log10(norm(U(ind,:)*h - xdpd(ind))/norm(xdpd(ind))), ...
    numel(ind), 20*log10(norm(dpd(end).yvalmod - xdpd)/norm(xdpd)));

% More models:




%% ===================================================================

%% DPD signals for step 3
if ~exist('comparison_type', 'var') || isempty(comparison_type)
    comparison_type = 'custom';
end
comparison_type = char(string(comparison_type));

if isempty(dpd)
    error('DPD:NoSignals', ...
        'No DPD signals defined. Fill in the DPD modeling section of %s.', mfilename);
end
for k = 1:numel(dpd)
    signal = dpd(k).yvalmod;
    if ~isnumeric(signal) || numel(signal) ~= numel(u) || ~all(isfinite(signal(:)))
        error('DPD:InvalidSignal', ...
            'dpd(%d) (%s): yvalmod must be a finite signal with %d samples.', ...
            k, char(string(dpd(k).modeltype)), numel(u));
    end
    dpd(k).yvalmod = signal(:);
end

executionPath = fullfile('results', ...
    ['experiment' filenamedate '_xy_execution_' comparison_type '.mat']);
save(executionPath, 'dpd', 'comparison_type');
fprintf('Saved %d DPD signals for main_3_testDPD: %s\n', numel(dpd), executionPath);
