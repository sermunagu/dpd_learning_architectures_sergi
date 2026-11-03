function [Pxx, fvec] = spectrumest(x, fs, plot_flag, method, fig)
    % SPECTRUM ESTIMATION
    %
    % Function to calculate the power spectral density (PSD) in dB/Hz and
    % the frequency axis for a given signal.
    %
    % Input parameters:
    % x         - Input signal.
    % fs        - Sampling frequency of the signal.
    % plot_flag - Optional flag to plot the PSD (default: false).
    % method    - Optional method for PSD estimation (default: 'Welch').
    %            If 'Welch', use Welch's method. If 'FFT', use FFT.
    %
    % Output parameters:
    % Pxx   - Power spectral density estimate in dB/Hz.
    % fvec  - Frequency vector corresponding to the PSD estimate.
    %
    % Author: Juan A. Becerra
    % Version: 27/06/2024

    % Set default values for optional arguments
    if nargin < 5
        figure();
    else
        figure(fig);
    end
    if nargin < 4
        method = 'welch';
    end
    if nargin < 3
        plot_flag = false;
    end

    % Choose method for PSD estimation
    switch lower(method)
        case 'welch'
%             % Parameters for Welch's method
%             wlen = 8e3;  % Length of each segment (window length)
%             olap = 5e3;  % Overlap between segments
%             nfft = 8e3;  % Number of FFT points
          
wlen = 1024;
olap = 768;   % 75%
nfft = 1024;
            % Kaiser window with beta = 50
            win = kaiser(wlen, 50);
            
            % Welch periodogram estimate using Kaiser window
            [Pxx, fvec] = pwelch(x, win, olap, nfft, fs);
            fvec = fvec-fs/2;
            Pxx = fftshift(Pxx);
            
            % Convert PSD to dB/Hz
            Pxx = 10 * log10(Pxx);
            
        case 'fft'
            % FFT-based method for PSD estimation
            fvec = linspace(-fs/2, fs/2, length(x));
            X = fftshift(fft(x));
            Pxx = 20 * log10(abs(X));
            
        otherwise
            error('Invalid method. Choose ''Welch'' or ''FFT''.');
    end
    
    % Plot the PSD estimate if plot_flag is true
    if plot_flag
        plot(fvec / 1e6, Pxx)
        xlabel('Frequency (MHz)'), ylabel('PSD (dBm/Hz)');
        title('Power Spectral Density Estimate')
    end
end
