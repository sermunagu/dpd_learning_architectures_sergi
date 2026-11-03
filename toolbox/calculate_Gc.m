function [G, Gc, Phc] = calculate_Gc(y, x, logging)
    % CALCULA_GC Calculates Average Gain, Peak Gain (Compression) and Peak Phase.
    %
    % Inputs:
    %   y : Output signal (captured)
    %   x : Input signal (reference)
    %
    % Outputs:
    %   G   : Average power gain (dB)
    %   Gc  : Instantaneous gain at the peak power sample (dB)
    %   Phc : Instantaneous phase at the peak power sample (degrees)

    if nargin==2
        logging=true;
    end
    % --- Local Helper Functions ---
    % Reference: 100 Ohm impedance assumed in original code
    calc_dBm      = @(s) 10*log10(mean(abs(s).^2)/100) + 30;
    calc_dBminst  = @(s) 10*log10(abs(s).^2/100) + 30;

    % --- Core Calculations ---
    % 1. Average Gain
    Pin_avg  = calc_dBm(x);
    Pout_avg = calc_dBm(y);
    G        = Pout_avg - Pin_avg;

    % 2. Instantaneous Gain and Phase
    G_inst   = calc_dBminst(y) - calc_dBminst(x);
    Ph_inst  = rad2deg(angle(y) - angle(x));
    
    % Wrap phase to [-180, 180]
    Ph_inst = mod(Ph_inst + 180, 360) - 180;

    % 3. Peak Analysis (Compression Point)
    % Instead of sorting, we directly find the peak of the input signal
    [~, peak_idx] = max(abs(x));
    Gc  = G_inst(peak_idx);
    Phc = Ph_inst(peak_idx);

    % --- Logging ---
    if(logging)
    fprintf('Gain Analysis:\n');
    fprintf('  Pin: %4.1f dBm | Pout: %4.1f dBm | Avg Gain: %4.2f dB\n', Pin_avg, Pout_avg, G);
    fprintf('  Peak Gain (Gc): %4.2f dB | Delta (G-Gc): %4.2f dB\n', Gc, G - Gc);
    end

    % --- Visualization ---
    fh = getOrCreateFigure('Calculate Gc', true);
    hold on; grid on;
    
    % Plot AM-AM Gain Curve
    plot(calc_dBminst(x), G_inst, '.', 'MarkerSize', 4, 'Color', [0.5 0.5 0.5]);
    
    % Plot Reference Lines
    x_lims = [min(calc_dBminst(x)), max(calc_dBminst(x))];
    plot(x_lims, [G G], 'r', 'LineWidth', 2, 'DisplayName', 'Avg Gain');
    plot(x_lims, [Gc Gc], 'g--', 'LineWidth', 2, 'DisplayName', 'Peak Gain');
    
    title('Instantaneous Gain vs Input Power');
    xlabel('Input Power (dBm)');
    ylabel('Gain (dB)');
    legend('Inst. Gain', 'Average Gain', 'Peak Gain', 'Location', 'best');
end