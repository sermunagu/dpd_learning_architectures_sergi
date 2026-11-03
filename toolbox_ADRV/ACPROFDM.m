function [ACPR, NMSE] = ACPR_OFDM_PRO(x, y, fs, BWch, BWeff, Foffs)

% ACPR_OFDM_PRO
% Multi-Carrier ACPR analysis for OFDM signals
%
% x      -> señal ideal
% y      -> señal medida
% fs     -> frecuencia de muestreo
% BWch   -> vector con ancho de cada canal
% BWeff  -> vector con ancho de integración
% Foffs  -> vector con frecuencia central de cada portadora

%% -------------------------------------------------
% 1. PREPROCESSING
%% -------------------------------------------------

x = x(:);
y = y(:);

x = x - mean(x);
y = y - mean(y);

NMSE = 20 * log10(norm(y/norm(y) - x/norm(x)));

%% -------------------------------------------------
% 2. PSD ESTIMATION
%% -------------------------------------------------

Nw = 2^16;
win = kaiser(Nw,38);

[PSD,f] = pwelch(y,win,Nw/2,Nw*2,fs,'centered');

PSDdB = 10*log10(PSD);

df = f(2)-f(1);

%% -------------------------------------------------
% 3. INITIALIZATION
%% -------------------------------------------------

numCar = length(Foffs);

ACPR = NaN(numCar,4);

fNyq = fs/2;

%% -------------------------------------------------
% 4. FIGURE
%% -------------------------------------------------
fh = getOrCreateFigure('Multi-Carrier Spectrum Analysis', true);
set(gcf,'Position',[100 100 1200 600]);

plot(f/1e6,PSDdB,'Color',[0.15 0.15 0.15],'LineWidth',0.7)
hold on
grid on

%% -------------------------------------------------
% 5. MAIN LOOP
%% -------------------------------------------------

for k = 1:numCar
    
    fc = Foffs(k);
    Be = BWeff(k);
    BW = BWch(k);
    
    adj_offsets = [-2 -1 1 2]*BW;
    
    %% MAIN BAND
    
    main_band = fc + [-Be/2 Be/2];
    
    idx = f >= main_band(1) & f <= main_band(2);
    
    Pmain = sum(PSD(idx))*df;
    
    col = hsv2rgb([(k-1)/numCar 0.8 0.8]);
    
    patch([f(idx);flipud(f(idx))]/1e6,...
          [PSDdB(idx);-200*ones(sum(idx),1)],...
          col,'FaceAlpha',0.35,'EdgeColor',col,'LineWidth',1.2,...
          'DisplayName',sprintf('Carrier %d',k))
      
    xline(fc/1e6,'--','Color',col,'HandleVisibility','off')
    
    %% ADJACENT CHANNELS
    
    for n = 1:4
        
        fc_adj = fc + adj_offsets(n);
        
        if abs(fc_adj) + Be/2 < fNyq
            
            adj_band = fc_adj + [-Be/2 Be/2];
            
            idx2 = f >= adj_band(1) & f <= adj_band(2);
            
            Padj = sum(PSD(idx2))*df;
            
            ACPR(k,n) = 10*log10(Padj/Pmain);
            
            patch([f(idx2);flipud(f(idx2))]/1e6,...
                  [PSDdB(idx2);-200*ones(sum(idx2),1)],...
                  [0.5 0.5 0.5],'FaceAlpha',0.15,...
                  'EdgeColor','none','HandleVisibility','off')
            
            text(fc_adj/1e6,max(PSDdB)+6,...
                sprintf('%.1f dB',ACPR(k,n)),...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'FontWeight','bold',...
                'Color',[0.3 0.3 0.3])
        end
        
    end
    
end

%% -------------------------------------------------
% 6. FORMATTING
%% -------------------------------------------------

xlabel('Frequency (MHz)')
ylabel('PSD (dB/Hz)')

title(sprintf('Multi-Carrier ACPR Analysis | NMSE %.2f dB | Carriers %d',NMSE,numCar))

legend('show','Location','northeastoutside')

xlim([-fs/2 fs/2]/1e6)

ylim([min(PSDdB)-10 max(PSDdB)+25])

end