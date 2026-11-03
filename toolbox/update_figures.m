%% Figure export folder
if ~exist('filenamedate', 'var') || isempty(filenamedate)
    filenamedate = datestr(clock, 30);
end

resultsFolder = 'results';
if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder);
end

figuresFolder = fullfile(resultsFolder, ['experiment' filenamedate]);
if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end
savedFigureHandles = gobjects(0);

%% Plot measured spectra
fh = getOrCreateFigure('Measured spectrum', true);       % Create or activate figure
savedFigureHandles(end+1) = fh;
spectrumest(u, fs, true, 'Welch', fh);                   % Plot input signal spectrum using Welch method
hold on
spectrumest(y, fs, true, 'Welch', fh);                   % Plot output signal spectrum on same figure

%% DPD AM/AM–AM/PM

fh = getOrCreateFigure('DPD AMAMn', true);
savedFigureHandles(end+1) = fh;

u1 = meas_out(1).u;  y1 = meas_out(1).y;
u2 = meas_out(end).u; y2 = meas_out(end).y;

yyaxis left
plot(abs(u1)/max(abs(u1)), abs(y1)/max(abs(y1)), '.', 'Color',[0 0.45 0.74],'MarkerSize',6); hold on
plot(abs(u2)/max(abs(u2)), abs(y2)/max(abs(y2)), '.', 'Color',[0.85 0.33 0.10],'MarkerSize',6)
ylabel('Normalized Output Amplitude')

yyaxis right
plot(abs(u1)/max(abs(u1)), 180/pi*fase_pmpi(angle(y1)-angle(u1)), '.', 'Color','k','MarkerSize',6), hold on
plot(abs(u2)/max(abs(u2)), 180/pi*fase_pmpi(angle(y2)-angle(u2)), '.', 'Color','r','MarkerSize',6)
ylabel('Phase Shift (deg)')

xlabel('Normalized Input Amplitude')
title('DPD AM/AM and AM/PM Characteristics')

grid on
set(gca,'FontSize',12)

%% DPD vs PA AM/AM comparison
fh = getOrCreateFigure('DPD AMAM', true);
savedFigureHandles(end+1) = fh;
plot(dBminst(u), dBminst(x*g), 'r.'); hold on       % DPD signal
plot(dBminst(x), dBminst(y), 'k.');                % PA signal
plot(dBminst(u), dBminst(y), 'b.');                % DPD+PA combined
legend('DPD', 'PA', 'DPD+PA', 'Location', 'southwest');
xlabel('Input power');
ylabel('Output power (dBm)');

%% Plot only DPD+PA
fh = getOrCreateFigure('DPD AMAM', false);
savedFigureHandles(end+1) = fh;
plot(dBminst(u), dBminst(y), '.');
xlabel('Input power');
ylabel('Output power (dBm)');

%% Plot gain (GAM)
fh = getOrCreateFigure('DPD GAM', false);
savedFigureHandles(end+1) = fh;
plot(dBminst(u), dBminst(y) - dBminst(u), '.');
xlabel('Input power');
ylabel('Gain G (dB)');

% getOrCreateFigure('DPD GAM', false);
% for i=[1,length(meas_out)-1]
% plot(dBminst(meas_out(i).u), dBminst(meas_out(i).y) - dBminst(meas_out(i).u), '.');hold on;
% end
% xlabel('Input power');
% ylabel('Gain G (dB)');
% axis([-45 -10 60 78])
% % 
% getOrCreateFigure('DPD GAM', false);
% for i=[1:length(meas_out)-1]
% plot(dBminst(meas_out(i).u), dBminst(meas_out(i).y) - dBminst(meas_out(i).u), '.');hold on;
% end
% xlabel('Input power');
% ylabel('Gain G (dB)');
% axis([-45 -10 60 78])

%% Plot output spectrum after DPD
fh = getOrCreateFigure('Spectrum acc', false);
savedFigureHandles(end+1) = fh;
spectrumest(y, fs, true, 'Welch', fh);
% % 
fh = getOrCreateFigure('Spectrum acc', true);
savedFigureHandles(end+1) = fh;
for i=[1:length(meas_out)-1]

spectrumest(meas_out(i).y, fs, true, 'Welch', fh); hold on,
end

%% Save generated figures
savedFigureHandles = savedFigureHandles(isgraphics(savedFigureHandles));
figNumbers = arrayfun(@(h) get(h, 'Number'), savedFigureHandles);
[~, uniqueIdx] = unique(figNumbers, 'stable');
figHandles = savedFigureHandles(uniqueIdx);
for ifig = 1:numel(figHandles)
    fh = figHandles(ifig);
    figName = get(fh, 'Name');
    if isempty(figName)
        figName = sprintf('Figure_%d', get(fh, 'Number'));
    end

    figName = regexprep(figName, '[<>:"/\\|?*]', '_');
    figName = regexprep(figName, '\s+', '_');

    pngPath = fullfile(figuresFolder, sprintf('%02d_%s.png', get(fh, 'Number'), figName));
    exportgraphics(fh, pngPath, 'Resolution', 300);
end
