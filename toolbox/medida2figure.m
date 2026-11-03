function medida2figure(medida)

PAPR = @(x) 20*log10(max(abs(x))/rms(x));
dBm = @(x) 10*log10(rms(x).^2/100)+30;

for i = 1:length(medida)

    descr{i} = char(medida(i).descr);

    nmse{i} = medida(i).performance.nmse_40;

    % -------- ACPR como string --------
    acpr_vals = medida(i).performance.ACPR;
    acpr{i} = strjoin(compose('%.2f',acpr_vals'),' | ');

    % -------- EVM como string --------
    evm_vals = medida(i).performance.evm_rms_med;
    evm{i} = strjoin(compose('%.3f',evm_vals'),' | ');

    Pin{i} = medida(i).Pin;
    Pout{i} = medida(i).Pout;

    PAPRx{i} = medida(i).PAPRx;

    Gdpd{i} = medida(i).Gdpd;

    Gsist{i} = medida(i).Gsist;
    I{i} = round(medida(i).data.I1*1000);
end


T = table(descr', nmse', acpr', evm', Pin', Pout', PAPRx', Gdpd', G', Gc', Gsist', I',...
    'VariableNames',{'Description','NMSE','ACPR','EVM','Pin','Pout','PAPR','Gdpd','G','Gc','Gsist', 'I(mA)'});


fh = findobj('Type','Figure','Name','Performance');

if isempty(fh)

    f = figure('Name','Performance');

    pos = get(f,'Position');
    pos(3) = 2*pos(3);
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

plot(1:length(medida),cell2mat(nmse));

xlabel('Iteration')
ylabel('NMSE (dB)')

drawnow

end