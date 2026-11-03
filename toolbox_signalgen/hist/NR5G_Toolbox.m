classdef NR5G_Toolbox
    % NR5G_TOOLBOX Unified Suite for 5G-NR Multi-carrier Generation & Analysis
    % Optimized: v5+v6 → v7

    methods (Static)

        %% --- SIGNAL GENERATION ---
        function [x, xs, info] = generate(info)

            Ncarriers = length(info.NPRB);

            % Parameter Initialization
            if ~isfield(info, 'Df'), info.Df = 2.^info.mu * 15e3; end
            if length(info.Df) == 1, info.Df = repmat(info.Df, 1, Ncarriers); end
            info.mu = log2(info.Df / 15e3);

            if ~isfield(info, 'NFFT')
                info.NFFT = 2.^nextpow2(info.NPRB * 12); % [OPT] Vectorizado
            end
            if ~isfield(info, 'fs'), info.fs = info.NFFT .* info.Df; end

            master_fsovs = isfield(info,'fsovs') * info.fsovs(1) + ...
                           ~isfield(info,'fsovs') * info.ovs(1) * info.fs(1);
            info.fsovs = master_fsovs;

            if ~isfield(info, 'Foff'),       info.Foff      = zeros(1, Ncarriers); end
            if ~isfield(info, 'BWeff'),      info.BWeff     = info.Df .* info.NPRB .* 12; end
            if ~isfield(info, 'seed'),       info.seed      = 999 + (1:Ncarriers); end
            if ~isfield(info, 'ffig'),       info.ffig      = zeros(1, Ncarriers); end
            if ~isfield(info, 'centralSC'),  info.centralSC = zeros(1, Ncarriers); end

            % [OPT] Pre-asignar xs para evitar concatenación dinámica
            xs_len_est = round(14 * info.Nslots * (info.NFFT(1) * (1 + 160/2048)) * master_fsovs / info.fs(1));
            xs = zeros(xs_len_est * 2, Ncarriers); % Estimación conservadora
            x  = zeros(xs_len_est * 2, 1);
            actual_len = 0;

            for is = 1:Ncarriers
                p.Df       = info.Df(is);
                p.mu       = info.mu(is);
                p.M        = info.M(is);
                p.NPRB     = info.NPRB(is);
                p.Nslots   = info.Nslots;
                p.BW       = info.BW(is);
                p.NFFT     = info.NFFT(is);
                p.fs       = info.fs(is);
                p.fsovs    = master_fsovs;
                p.ovs_local = master_fsovs / p.fs;
                p.Foff     = info.Foff(is);
                p.BWeff    = info.BWeff(is);
                p.seed     = info.seed(is);
                p.centralSC = info.centralSC(is);
                p.ffig     = info.ffig(is);

                if Ncarriers == 1
                    tipoSS.filtro = info.SpectrumShaping;
                else
                    tipoSS.filtro = info.SpectrumShaping{is};
                end
                tipoSS.param = info.SpectrumShapingParam(is);

                clip.flag  = info.fclipCarrier(is);
                clip.PAPRd = info.PAPRdCarrier(is);

                xs_tmp = NR5G_Toolbox.OFDM_core(p, tipoSS, clip);
                N = length(xs_tmp);

                if actual_len == 0, actual_len = N; end

                % [OPT] Escritura directa en lugar de concatenación
                xs(1:N, is) = xs_tmp;

                t     = (0:N-1).' / master_fsovs;
                shift = exp(1i * 2 * pi * t * p.Foff);
                x(1:N) = x(1:N) + xs_tmp .* shift; % [OPT] Suma in-place
            end

            % Recortar al tamaño real
            x  = x(1:actual_len);
            xs = xs(1:actual_len, :);

            if ~any(info.centralSC), x = x - mean(x); end
            x = x / max(abs(x));

            if isfield(info, 'fclip') && info.fclip
                x = NR5G_Toolbox.apply_clipping(x, info.PAPRd, 'Global');
            end
        end

        %% --- SIGNAL ANALYSIS ---
        function [ACPR, ACPR2, EVM, NMSE] = analyze(x_ref, y_med, info, fc_mhz)

            NS    = length(info.NPRB);
            fsovs = info.fsovs(1);

            % [OPT] Pre-asignar salidas
            ACPR  = zeros(2, NS);
            ACPR2 = zeros(2, NS);
            EVM   = zeros(1, NS);
            NMSE  = zeros(1, NS);

            N = length(y_med);
            t_full = (0:N-1).' / fsovs; % [OPT] Calcular t una sola vez

            for is = 1:NS
                Df   = info.Df(is);
                NPRB = info.NPRB(is);
                NFFT = info.NFFT(is);

                fs_base     = NFFT * Df;
                ovs_analisis = min(4, floor(fsovs / fs_base));
                fsint       = ovs_analisis * fs_base;

                shift  = exp(-1i * 2 * pi * t_full * info.Foff(is)); % [OPT] Reutiliza t_full
                x_base = x_ref .* shift;
                y_base = y_med .* shift;

                x_res = NR5G_Toolbox.FFTinterpolate(x_base, fsovs, fsint);
                y_res = NR5G_Toolbox.FFTinterpolate(y_base, fsovs, fsint);

                fc_actual = fc_mhz + info.Foff(is) / 1e6;
                [ACPR(:,is), ACPR2(:,is), EVM(is), NMSE(is)] = ...
                    NR5G_Toolbox.analyze_OFDM_core(x_res, y_res, NPRB, info.mu(is), ...
                    info.M(is), info.BW(is), fsint, ovs_analisis, info.Nslots(is), ...
                    info.centralSC(is), fc_actual);
            end
        end
    end

    methods (Static, Access = private)

        function x = OFDM_core(p, tipoSS, clip)
            rng(p.seed);
            Nsymb = 14 * p.Nslots;
            Nsc   = p.NPRB * 12;
            NFFT  = p.NFFT;
            k     = log2(p.M);

            % QAM Mapping
            Bn     = randi([0 1], Nsymb * Nsc * k, 1); % [OPT] Columna directa
            M1     = sqrt(p.M);
            alf    = -(M1-1):2:(M1-1);
            Bn_res = reshape(Bn, k, []).';
            idx_i  = NR5G_Toolbox.gray2de(Bn_res(:, 1:k/2)) + 1;
            idx_q  = NR5G_Toolbox.gray2de(Bn_res(:, k/2+1:end)) + 1;
            An     = (alf(idx_i) + 1i * alf(idx_q)).';

            % Subcarrier Mapping
            An_symb = reshape(An, Nsc, Nsymb);
            pad     = NFFT - Nsc;

            if p.centralSC
                An_symb = [An_symb(Nsc/2+1:end,:); zeros(pad, Nsymb); An_symb(1:Nsc/2,:)];
            else
                An_symb = [zeros(1, Nsymb); An_symb(Nsc/2+1:end,:); zeros(pad-1, Nsymb); An_symb(1:Nsc/2,:)];
            end

            % IFFT
            Xn_symb = ifft(An_symb); % [OPT] MATLAB usa FFT optimizada por columnas de matriz

            NCP0 = round(160/2048 * NFFT);
            NCP  = round(144/2048 * NFFT);

            % [OPT] Pre-asignar Xn
            len_per_sym = NFFT + NCP;
            total_len   = Nsymb * len_per_sym + Nsymb * (NCP0 - NCP); % aprox conservadora
            Xn = zeros(total_len, 1);
            ptr = 1;
            for i = 1:Nsymb
                cp  = NCP + (mod(i-1,7)==0) * (NCP0 - NCP); % [OPT] Sin if/else
                seg = [Xn_symb(end-cp+1:end, i); Xn_symb(:, i)];
                L   = length(seg);
                Xn(ptr:ptr+L-1) = seg;
                ptr = ptr + L;
            end
            Xn = Xn(1:ptr-1); % Recortar

            x = NR5G_Toolbox.spectrum_shaping(Xn, NFFT * p.Df, p.ovs_local, p.BWeff, tipoSS);
            x = x / norm(x);
            if clip.flag
                x = NR5G_Toolbox.apply_clipping(x, clip.PAPRd, 'Carrier');
            end
        end

        function [ACPR, ACPR2, EVM, NMSE] = analyze_OFDM_core(x_ref, y_med, NPRB, mu, M, BW, fs, ovs, Nslots, centralSC, fc)
            if ~centralSC
                x_ref = x_ref - mean(x_ref);
                y_med = y_med - mean(y_med);
            end

            % [OPT] norm() solo una vez
            norm_x = norm(x_ref);
            y_med  = y_med * (norm_x / norm(y_med));

            Df   = 2^mu * 15e3;
            Nsc  = NPRB * 12;
            NFFT = 2^nextpow2(Nsc);

            NMSE = 20 * log10(norm(y_med - x_ref) / norm_x);

            % PSD con Welch
            win  = kaiser(2^12, 38);
            [PSD, f_axis] = pwelch(y_med, win, [], 2^12, fs, 'centered');

            % [OPT] bandpower calculado una sola vez para banda principal
            band_main = [-0.5*Nsc*Df, 0.5*Nsc*Df];
            Pmain_lin = bandpower(y_med, fs, band_main);
            Pmain     = 10*log10(Pmain_lin);

            ACPR = zeros(2,1);
            if ovs >= 3
                ACPR(1) = 10*log10(bandpower(y_med, fs, -BW + band_main)) - Pmain;
                ACPR(2) = 10*log10(bandpower(y_med, fs,  BW + band_main)) - Pmain;
            end
            ACPR2 = [0; 0];

            % EVM
            [~, x_syms] = NR5G_Toolbox.quita_cp(x_ref, ovs, NPRB, Nslots);
            [~, y_syms] = NR5G_Toolbox.quita_cp(y_med, ovs, NPRB, Nslots);

            X_f = fft(x_syms(1:ovs:end, :), NFFT);
            Y_f = fft(y_syms(1:ovs:end, :), NFFT);

            if centralSC
                idx = [NFFT-Nsc/2+1:NFFT, 1:Nsc/2];
            else
                idx = [NFFT-Nsc/2+1:NFFT, 2:Nsc/2+1];
            end

            s_tx = X_f(idx, :);
            s_rx = Y_f(idx, :);
            s_rx = s_rx * (norm(s_tx) / norm(s_rx));
            EVM  = (norm(s_rx(:) - s_tx(:)) / norm(s_tx(:))) * 100;

            NR5G_Toolbox.plot_data(f_axis, 10*log10(PSD) - Pmain, s_tx, s_rx, fc, EVM);
        end

        function y = spectrum_shaping(x, fs, ovs, BW, config)
            ovs = ovs(1);
            if strcmp(config.filtro, 'BPideal')
                x_up  = NR5G_Toolbox.FFTinterpolate(x, fs, fs * ovs);
                L     = length(x_up);
                BW_bins = ceil(L * 0.52 * BW / (fs * ovs));
                H     = zeros(L, 1);
                H(1:BW_bins) = 1;
                H(end-BW_bins+2:end) = 1;
                y = ifft(fft(x_up) .* H);
            else
                y = NR5G_Toolbox.FFTinterpolate(x, fs, fs * ovs);
            end
        end

        function x = apply_clipping(x, target_papr, ~)
            p  = 20 * log10(max(abs(x)) / rms(x));
            if p > target_papr
                th   = 10^((target_papr - p) / 20);
                mask = abs(x) > th;
                x(mask) = th * exp(1i * angle(x(mask))); % [OPT] Índice lógico en lugar de doble indexación
            end
        end

        function y = FFTinterpolate(x, fs_in, fs_out)
            fs_out = fs_out(1);
            if abs(fs_in - fs_out) < 1, y = x; return; end
            N    = length(x);
            [P, Q] = rat(fs_out / fs_in, 1e-6);
            Nnew = round(N * P / Q);
            X    = fft(x) / sqrt(N);
            Y    = zeros(Nnew, 1);
            hN   = floor(N/2);
            hNnew = floor(Nnew/2);
            if P > Q % Upsampling
                Y(1:ceil(N/2))      = X(1:ceil(N/2));
                Y(end-hN+1:end)     = X(end-hN+1:end);
            else      % Downsampling
                Y(1:ceil(Nnew/2))   = X(1:ceil(Nnew/2));
                Y(end-hNnew+1:end)  = X(end-hNnew+1:end);
            end
            y = ifft(Y) * sqrt(Nnew);
        end

        function [y, Y] = quita_cp(x, ovs, NRB, Nslots)
            ovs  = ovs(1);
            NFFT = 2^nextpow2(NRB * 12);
            cp0  = round(160/2048 * NFFT * ovs);
            cp   = round(144/2048 * NFFT * ovs);
            L_sym = NFFT * ovs;
            Nsym  = 14 * Nslots;

            % [OPT] Pre-asignar Y
            Y   = zeros(L_sym, Nsym);
            ptr = 1;
            for i = 1:Nsym
                c   = cp + (mod(i-1,7)==0) * (cp0 - cp); % [OPT] Sin if/else
                ptr = ptr + c;
                Y(:, i) = x(ptr:ptr+L_sym-1);
                ptr = ptr + L_sym;
            end
            y = Y(:);
        end

        function d = gray2de(g)
            [rows, cols] = size(g);
            b = zeros(rows, cols);
            b(:,1) = g(:,1);
            for i = 2:cols
                b(:,i) = xor(b(:,i-1), g(:,i)); % [OPT] Operación vectorizada por columna
            end
            b = fliplr(b);
            d = (b * (2 .^ (0:cols-1)).')'; % [OPT] Producto matricial en lugar de bucle
        end

        function plot_data(f, psd, s_tx, s_rx, fc, evm)
            % [OPT] Guardar handles para evitar findobj en cada llamada
            persistent h_spec h_const;

            nm = 'NR5G Analysis - Spectrum';
            if isempty(h_spec) || ~isvalid(h_spec)
                h_spec = figure('Name', nm);
            end
            figure(h_spec); cla;
            plot(f * 1e-6 + fc, psd); grid on;
            xlabel('Frecuencia (MHz)'); ylabel('PSD (dB)');

            nm_c = sprintf('Constellation Carrier %.1f MHz', fc);
            if isempty(h_const) || ~isvalid(h_const)
                h_const = figure('Name', nm_c);
            end
            figure(h_const); cla;
            plot(real(s_rx(:)), imag(s_rx(:)), '.'); hold on;
            plot(real(s_tx(:)), imag(s_tx(:)), 'g+');
            title(sprintf('EVM: %.2f%%', evm)); grid on; axis square;
        end
    end
end