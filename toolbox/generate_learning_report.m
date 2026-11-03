function pdfPath = generate_learning_report(filenamedate, exp_config, info_signal)
%GENERATE_LEARNING_REPORT Build a PDF report for one completed learning experiment.
% Run from the project root after main_1_learnDPD, or pass the
% timestamp of an existing experiment with its saved .mat file.
% The title shows the learning method of the experiment (ILC, DLA or ILA,
% from exp_config.DLmethod); older experiments without that field get a
% generic title.

if nargin < 1 || isempty(filenamedate)
    error('generate_learning_report:MissingExperiment', 'Pass the experiment timestamp.');
end
filenamedate = char(string(filenamedate));
experimentName = ['experiment' filenamedate];
resultsRoot = fullfile(pwd, 'results');
experimentFile = fullfile(resultsRoot, [experimentName '.mat']);
if nargin < 3
    if ~isfile(experimentFile)
        error('generate_learning_report:MissingExperiment', ...
            'Experiment data not found: %s', experimentFile);
    end
    saved = load(experimentFile, 'exp_config', 'info_signal');
    exp_config = saved.exp_config;
    info_signal = saved.info_signal;
end

reportDir = fullfile(resultsRoot, experimentName);
workbook = fullfile(reportDir, 'performance_results.xlsx');
if ~isfile(workbook)
    error('generate_learning_report:MissingPerformance', ...
        'Performance table not found: %s', workbook);
end
performance = readcell(workbook);
if size(performance, 1) < 2
    error('generate_learning_report:EmptyPerformance', ...
        'Performance table has no measurements: %s', workbook);
end

if isfield(exp_config, 'DLmethod') && ~isempty(exp_config.DLmethod)
    reportTitle = [char(string(exp_config.DLmethod)) ' Results'];
else
    reportTitle = 'DPD Learning Results';
end

texName = [experimentName '_report.tex'];
texPath = fullfile(reportDir, texName);
pdfPath = fullfile(reportDir, [experimentName '_report.pdf']);
[fid, message] = fopen(texPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('generate_learning_report:WriteFailed', 'Cannot write %s: %s', texPath, message);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '\\documentclass[10pt,a4paper]{article}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage[margin=18mm]{geometry}\n');
fprintf(fid, '\\setlength{\\parindent}{0pt}\n');
fprintf(fid, '\\setlength{\\parskip}{4pt}\n');
fprintf(fid, '\\begin{document}\n');
fprintf(fid, '\\begin{center}{\\LARGE\\textbf{%s}}\\\\[4pt]\n', latex_escape(reportTitle));
fprintf(fid, '{\\small %s}\n\\end{center}\n', latex_escape(experimentName));
fprintf(fid, '\\section*{Experiment}\n');
if isfield(exp_config, 'DLmethod')
    fprintf(fid, '\\textbf{Learning method:} %s\\\\\n', latex_escape(exp_config.DLmethod));
end
if isfield(exp_config, 'gainMode')
    fprintf(fid, '\\textbf{Gain mode:} %s\\\\\n', latex_escape(exp_config.gainMode));
end
fprintf(fid, '\\textbf{Waveform ID:} %d\\\\\n', exp_config.waveform_id);
if isfield(info_signal, 'BW')
    fprintf(fid, '\\textbf{Bandwidth (Hz):} %s\\\\\n', ...
        latex_escape(mat2str(info_signal.BW)));
end
if isfield(info_signal, 'Foff')
    fprintf(fid, '\\textbf{Frequency offset (Hz):} %s\\\\\n', ...
        latex_escape(mat2str(info_signal.Foff)));
end

fprintf(fid, '\\section*{Performance results}\n');
ncol = size(performance, 2);
fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');
fprintf(fid, '\\begin{tabular}{|%s}\\hline\n', repmat('c|', 1, ncol));
for row = 1:size(performance, 1)
    entries = cell(1, ncol);
    for col = 1:ncol
        entries{col} = latex_escape(value_text(performance{row, col}));
    end
    fprintf(fid, '%s \\\\ \\hline\n', strjoin(entries, ' & '));
end
fprintf(fid, '\\end{tabular}%%\n}\n');

figureNames = {'DPD_AMAMn', 'DPD_AMAM', 'DPD_GAM', 'Spectrum_acc'};
figureTitles = {'DPD AM/AM and AM/PM', 'DPD and PA AM/AM', ...
    'DPD gain', 'Accumulated spectrum'};
fprintf(fid, '\\section*{Figures}\n');
for pair = 1:2
    for side = 1:2
        idx = 2*(pair-1) + side;
        matches = dir(fullfile(reportDir, ['*_' figureNames{idx} '.png']));
        if side == 2
            fprintf(fid, '\\hfill\n');
        end
        fprintf(fid, '\\begin{minipage}{0.48\\textwidth}\\centering\n');
        if isempty(matches)
            fprintf(fid, '\\fbox{Figure unavailable}\\\\\n');
        else
            fprintf(fid, '\\includegraphics[width=\\linewidth]{%s}\\\\\n', ...
                matches(1).name);
        end
        fprintf(fid, '{\\small %s}\n\\end{minipage}\n', ...
            latex_escape(figureTitles{idx}));
    end
    fprintf(fid, '\\par\\vspace{0.6em}\n');
end
fprintf(fid, '\\end{document}\n');
clear cleanup;

command = sprintf('cd /d "%s" && pdflatex -interaction=nonstopmode -halt-on-error "%s"', ...
    reportDir, texName);
[status, output] = system(command);
if status ~= 0 || ~isfile(pdfPath)
    error('generate_learning_report:LatexFailed', ...
        'PDF compilation failed for %s. Compiler output:\n%s', texPath, output);
end
fprintf('%s PDF report saved: %s\n', reportTitle, pdfPath);
end

function result = value_text(value)
if ischar(value) || isstring(value)
    result = char(string(value));
elseif isnumeric(value) && isscalar(value)
    if isnan(value)
        result = 'NaN';
    else
        result = sprintf('%.3f', value);
    end
elseif islogical(value) && isscalar(value)
    result = char(string(value));
else
    result = '';
end
end

function result = latex_escape(value)
value = char(string(value));
result = '';
for k = 1:numel(value)
    switch value(k)
        case '\'
            result = [result '\textbackslash{}']; %#ok<AGROW>
        case {'&', '%', '$', '#', '_', '{', '}'}
            result = [result '\' value(k)]; %#ok<AGROW>
        case '~'
            result = [result '\textasciitilde{}']; %#ok<AGROW>
        case '^'
            result = [result '\textasciicircum{}']; %#ok<AGROW>
        otherwise
            result = [result value(k)]; %#ok<AGROW>
    end
end
end
