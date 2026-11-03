%% Master 5G-NR waveform configuration
% Base: config_signal_2carriers_20MHz_sep_100MHz
%
% Usage:
%   waveform_id = 4;                 % Select waveform 1..8
%   config_signal_master_5waveforms  % Leaves selected config in info_signal
%
% Optional:
%   generate_all_waveforms = true;
%   config_signal_master_5waveforms
%   % Leaves x_waveforms, xs_waveforms and info_waveforms with all 8 signals.

if ~exist('waveform_id', 'var') || isempty(waveform_id)
    waveform_id = 1;
end
if ~exist('generate_all_waveforms', 'var') || isempty(generate_all_waveforms)
    generate_all_waveforms = false;
end

common.Df      = 60e3;
common.NFFT    = 2048;
common.Nslots  = 4;
common.ovs     = 4;
common.fsovs   = 491.52e6;
common.M       = 256;
common.seed0   = 1000;
common.centralSC = 0;
common.ffig      = 1;
common.fclipCarrier = 0;
common.PAPRdCarrier = 10.5;
common.SpectrumShaping = 'BPideal';
common.SpectrumShapingParam = 0;

waveform_configs = localWaveformConfig(common, ...
    1, [6], [5e6], [0], [256]);

waveform_configs(2) = localWaveformConfig(common, ...
    1, [6], [5e6], [-77.5e6], [256]);

waveform_configs(3) = localWaveformConfig(common, ...
    1, [6], [5e6], [77.5e6], [256]);

waveform_configs(4) = localWaveformConfig(common, ...
    2, [24, 24], [20e6, 20e6], [-70e6, 70e6], [256, 256]);

waveform_configs(5) = localWaveformConfig(common, ...
    2, [107, 107], [80e6, 80e6], [-40e6, 40e6], [256, 256]);

waveform_configs(6) = localWaveformConfig(common, ...
    1, [24], [20e6], [0], [256]);

waveform_configs(7) = localWaveformConfig(common, ...
    1, [65], [50e6], [0], [256]);

waveform_configs(8) = localWaveformConfig(common, ...
    1, [135], [100e6], [0], [256]);

waveform_configs(1).maskerr = [-1, -150e6/(common.fsovs/2), 0;
    -150e6/(common.fsovs/2), 150e6/(common.fsovs/2), 1;
    150e6/(common.fsovs/2), 1, 0];
for iwaveform = 2:numel(waveform_configs)
    waveform_configs(iwaveform).maskerr = [];
end

if waveform_id < 1 || waveform_id > numel(waveform_configs)
    error('waveform_id must be an integer from 1 to %d.', numel(waveform_configs));
end

info_signal = waveform_configs(waveform_id);
mask = info_signal.mask;
maskerr = info_signal.maskerr;

if generate_all_waveforms
    x_waveforms = cell(1, numel(waveform_configs));
    xs_waveforms = cell(1, numel(waveform_configs));
    info_waveforms = cell(1, numel(waveform_configs));

    for iwaveform = 1:numel(waveform_configs)
        [x_waveforms{iwaveform}, xs_waveforms{iwaveform}, info_waveforms{iwaveform}] = ...
            genera_5GNR_multicarrier_v5(waveform_configs(iwaveform));
    end
end

%% Independent test parameters
PAPRd = 12;
RMSin = 0;

function info = localWaveformConfig(common, ncarriers, nprb, bw, foff, modulation)
    info = struct();

    info.Df      = localRepeat(common.Df, ncarriers);
    info.M       = modulation;
    info.NPRB    = nprb;
    info.BW      = bw;
    info.Nslots  = localRepeat(common.Nslots, ncarriers);
    info.NFFT    = localRepeat(common.NFFT, ncarriers);
    info.ovs     = localRepeat(common.ovs, ncarriers);
    info.fsovs   = localRepeat(common.fsovs, ncarriers);
    info.Foff    = foff;
    info.BWeff   = info.Df .* info.NPRB .* 12;

    info.seed      = common.seed0 + (0:ncarriers-1);
    info.centralSC = localRepeat(common.centralSC, ncarriers);
    info.ffig      = localRepeat(common.ffig, ncarriers);

    info.fclipCarrier = localRepeat(common.fclipCarrier, ncarriers);
    info.fclip        = 0;
    info.PAPRdCarrier = localRepeat(common.PAPRdCarrier, ncarriers);
    info.PAPRd        = 12;

    if ncarriers == 1
        info.SpectrumShaping = common.SpectrumShaping;
    else
        info.SpectrumShaping = repmat({common.SpectrumShaping}, 1, ncarriers);
    end
    info.SpectrumShapingParam = localRepeat(common.SpectrumShapingParam, ncarriers);

    [info.mask, info.maskerr] = localSpectrumMasks(info);
end

function value = localRepeat(value, nitems)
    value = repmat(value, 1, nitems);
end

function [mask, maskerr] = localSpectrumMasks(info)
    fsnyq = info.fsovs(1)/2;
    fmin = (info.Foff - info.BWeff/2) / fsnyq;
    fmax = (info.Foff + info.BWeff/2) / fsnyq;

    [fmin, order] = sort(fmin);
    fmax = fmax(order);

    fmin = max(fmin, -1);
    fmax = min(fmax, 1);

    mask = [];
    maskerr = [];
    edge = -1;

    for iband = 1:numel(fmin)
        if fmin(iband) > edge
            mask = [mask; edge, fmin(iband), 0];
            maskerr = [maskerr; edge, fmin(iband), 1];
        end

        mask = [mask; fmin(iband), fmax(iband), 1];
        maskerr = [maskerr; fmin(iband), fmax(iband), 0];
        edge = fmax(iband);
    end

    if edge < 1
        mask = [mask; edge, 1, 0];
        maskerr = [maskerr; edge, 1, 1];
    end
end
