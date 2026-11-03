function meas2figure(meas, resultsPath)

if nargin < 2 || isempty(resultsPath)
    if evalin('base', 'exist(''filenamedate'', ''var'')')
        filenamedate = evalin('base', 'filenamedate');
    else
        filenamedate = datestr(clock, 30);
    end
    resultsPath = fullfile('results', ['experiment' filenamedate]);
end

if ~isfolder(resultsPath)
    [mkdirOK, mkdirMsg] = mkdir(resultsPath);
    if ~mkdirOK
        warning('meas2figure:mkdirFailed', ...
            'Could not create results folder "%s": %s', resultsPath, mkdirMsg);
        resultsPath = pwd;
    end
end

PAPR = @(x) 20*log10(max(abs(x))/rms(x));
dBm = @(x) 10*log10(rms(x).^2/100)+30;

for i = 1:length(meas)

    description{i} = char(meas(i).descr);

    nmse{i} = meas(i).performance.NMSE;

    % -------- ACPR as string --------
    acpr_vals = meas(i).performance.ACPR;
    acpr{i} = strjoin(compose('%.2f',acpr_vals'),' | ');

    % -------- EVM as string --------
    evm_vals = meas(i).performance.EVM;
    evm{i} = strjoin(compose('%.3f',evm_vals'),' | ');

    RMSin{i} = meas(i).Pin-meas(i).Gin;
    Pin{i} = meas(i).Pin;
    Pout{i} = meas(i).Pout;
    RMSout{i} = meas(i).Pout-meas(i).Lout;
    %Gsist{i} = Pout{i}-Pin{i};
    PAPRx{i} = meas(i).PAPRx;
    PAPRxCFR{i} = meas(i).PAPRxCFR;

    Gdpd{i} = meas(i).Gdpd;

    
    Gsist{i} = meas(i).Pout-meas(i).Pin+meas(i).Gin+meas(i).Gdpd;
    G0{i}=meas(i).G0;
    GDUT{i} = meas(i).Gavg;
    Gcsist{i} = meas(i).Gc+meas(i).Gin;
    Gc{i} = meas(i).Gc;
    I{i} = round(meas(i).data.I1*1000);
    mu{i} = meas(i).mu;
    PAE{i} = (10^((Pout{i}-30)/10)-10^((Pin{i}-30)/10))/(meas(i).data.I1*meas(i).data.V1)*100;

end


T = table(description', nmse', acpr', evm', RMSin',Pin', Pout', RMSout', PAPRx',PAPRxCFR', Gsist',G0', Gdpd', GDUT', Gc', Gcsist', I',mu',PAE',...
'VariableNames',{'Description','NMSE','ACPR','EVM','RMSin','Pin','Pout','RMSout','PAPRx','PAPRxCFR','Gsist','G0','Gdpd','GDUT','Gc','Gcsist', 'I(mA)', 'mu','PAE'});


fh = findobj('Type','Figure','Name','Performance');

if isempty(fh)

    f = figure('Name','Performance');

    pos = get(f,'Position');
    pos(3) = 3.5*pos(3);
    set(f,'Position',pos);

else

    figure(fh(1)); clf;

end


uitable('Data',T{:,:},...
        'ColumnName',T.Properties.VariableNames,...
        'RowName',T.Properties.RowNames,...
        'Units','Normalized',...
        'Position',[0 0 1 1]);

drawnow


fh = findobj('Type','Figure','Name','NMSE');

if isempty(fh)

    figure('Name','NMSE')

else

    figure(fh(1)); clf;

end

plot(1:length(meas),cell2mat(nmse));

xlabel('Iteration')
ylabel('NMSE (dB)')

drawnow

writetable(T, fullfile(resultsPath, 'performance_results.xlsx'));

end
