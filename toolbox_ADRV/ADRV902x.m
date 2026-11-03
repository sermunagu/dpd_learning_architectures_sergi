% Sample Script to set up ADRV902x for playback and capture
% Created: 01-MAY-2025
% Start with installation of ADRV9029 GUI version
%   - adrv9029-customerpkg-broad-market-release.zip
%   - GUI Version: 6.4.0.17
%   - DLL Version: 6.4.0.14
% Default path: C:\\Program Files\\Analog Devices\\ADRV9025 Transceiver ...
% Evaluation Software_x64_FULL\\adrvtrx_dll.dll
% kevin.chuang@analog.com


classdef ADRV902x < handle
    properties
        link;
        txSampleRate = 245.76e6;
        bufferSize = 245760;
        rxSampleRate = 122.88e6;
        orxSampleRate = 245.76e6;
        DeframerNp = 16;
        profile = 26;        
        SelTxChannels = 1;
        SelRxChannels = 16;
        txChList;
        rxChList;
        gpioSelList;
        captureBandList;
        captureTypeList;
        captureSizeList;
        captureBandDirList;
        capturePulseWidthResList;
        lutSelList;
        lutBankSelList;
        modelSelList;
        compSizeList;
        aux_LO=0;
        use_adrvtrx_dll = 0;
    end
    
    methods

        % Input: profile: profile number (14)
        function obj = ADRV902x(profile, txlo, refClock, set_aux_LO, use_adrvtrx_dll, skipInit)
            if nargin < 4
                set_aux_LO = 0;
            end
            if nargin < 5
                use_adrvtrx_dll = 1;
            end
            if nargin < 6, skipInit = false; end % Default: Program the board

            obj.use_adrvtrx_dll = use_adrvtrx_dll;
            if exist('set_aux_LO','var')
                obj.aux_LO=set_aux_LO;

            end
            %Make DLL visible to Matlab
            if (use_adrvtrx_dll == 1)
                NET.addAssembly('C:\\Program Files\\Analog Devices\\ADRV9025 Transceiver Evaluation Software_x64_FULL\\adrvtrx_dll.dll');
            else
                NET.addAssembly('C:\\Program Files\\Analog Devices\\ADRV9025 Transceiver Evaluation Software_x64_FULL\\adrvtrx_dll.dll');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.txChList = {adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1, adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX2, adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX3, adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX4};
            obj.rxChList = {adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX1, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX2, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX3, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX4, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX1, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX2, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX3, adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX4};
            obj.compSizeList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdActuatorCompanderSize_e.ADI_ADRV9010_EXT_DPD_ACT_COMPANDER_8_BITS, adrv9010_dll.Types.adi_adrv9010_ExtDpdActuatorCompanderSize_e.ADI_ADRV9010_EXT_DPD_ACT_COMPANDER_9_BITS};
            obj.gpioSelList = {adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_00, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_01, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_02,...
                adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_03, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_04, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_05, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_06,...
                adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_07, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_08, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_09, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_10,...
                adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_11, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_12, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_13, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_14,...
                adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_15, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_16, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_17, adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_18,...
                adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID};
            obj.captureBandList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBand_e.ADI_ADRV9010_EXT_DPD_CAPTURE_POWER_BAND_0, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBand_e.ADI_ADRV9010_EXT_DPD_CAPTURE_POWER_BAND_1, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBand_e.ADI_ADRV9010_EXT_DPD_CAPTURE_POWER_BAND_2, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBand_e.ADI_ADRV9010_EXT_DPD_CAPTURE_POWER_BAND_3};
            obj.captureBandDirList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBandDir_e.ADI_ADRV9010_EXT_DPD_CAPTURE_BAND_REACHED_ANY_ORDER, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBandDir_e.ADI_ADRV9010_EXT_DPD_CAPTURE_BAND_REACHED_ASCENDING, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureBandDir_e.ADI_ADRV9010_EXT_DPD_CAPTURE_BAND_REACHED_DESCENDING};
            obj.capturePulseWidthResList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdCapturePulseWidthRes_e.ADI_ADRV9010_EXT_DPD_CAPTURE_PW_RES_1X, adrv9010_dll.Types.adi_adrv9010_ExtDpdCapturePulseWidthRes_e.ADI_ADRV9010_EXT_DPD_CAPTURE_PW_RES_256X, adrv9010_dll.Types.adi_adrv9010_ExtDpdCapturePulseWidthRes_e.ADI_ADRV9010_EXT_DPD_CAPTURE_PW_RES_65536X, adrv9010_dll.Types.adi_adrv9010_ExtDpdCapturePulseWidthRes_e.ADI_ADRV9010_EXT_DPD_CAPTURE_PW_RES_16777216X};
            obj.captureTypeList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureType_e.ADI_ADRV9010_EXT_DPD_CAPTURE_IMMEDIATE_TRIGGER, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureType_e.ADI_ADRV9010_EXT_DPD_CAPTURE_POWER_LEVEL_TRIGGER};
            obj.captureSizeList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_32_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_64_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_128_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_256_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_512_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_1024_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_2048_SAMPLES, adrv9010_dll.Types.adi_adrv9010_ExtDpdCaptureSize_e.ADI_ADRV9010_EXT_DPD_CAPTURE_SIZE_4096_SAMPLES};
            obj.lutSelList =  {adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT0, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT1, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT2, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT3, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT4, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT5,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT6, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT7,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT8, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT9,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT10, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT11,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT12, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT13,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT14, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT15,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT16, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT17,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT18, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT19,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT20, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT21,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT22, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT23,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT24, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT25,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT26, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT27,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT28, adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT29,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT30,        adrv9010_dll.Types.adi_adrv9010_ExtDpdLut_e.ADI_ADRV9010_EXT_DPD_LUT31};
            obj.lutBankSelList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdLutBank_e.ADI_ADRV9010_EXT_DPD_LUT_BANK0, adrv9010_dll.Types.adi_adrv9010_ExtDpdLutBank_e.ADI_ADRV9010_EXT_DPD_LUT_BANK1, adrv9010_dll.Types.adi_adrv9010_ExtDpdLutBank_e.ADI_ADRV9010_EXT_DPD_LUT_BANK2, adrv9010_dll.Types.adi_adrv9010_ExtDpdLutBank_e.ADI_ADRV9010_EXT_DPD_LUT_BANK3};
            obj.modelSelList = {adrv9010_dll.Types.adi_adrv9010_ExtDpdModelSel_e.ADI_ADRV9010_EXT_DPD_MODEL0, adrv9010_dll.Types.adi_adrv9010_ExtDpdModelSel_e.ADI_ADRV9010_EXT_DPD_MODEL1, adrv9010_dll.Types.adi_adrv9010_ExtDpdModelSel_e.ADI_ADRV9010_EXT_DPD_MODEL2, adrv9010_dll.Types.adi_adrv9010_ExtDpdModelSel_e.ADI_ADRV9010_EXT_DPD_MODEL3};
            
            %Create an Instance of the Class
            obj.link = adrv9010_dll.AdiEvaluationSystem.Instance;
            obj.profile = profile;
            fprintf ('User Case: %d LinkSharing Profile\n',obj.profile);
            fprintf ('Instance Created\n');
            connect = false;
            
            if(obj.link.IsConnected() == false)
                connect = true;
                obj.link.platform.board.Client.Connect('192.168.1.10', 55556);
                fprintf ('Connecting\n');
            end
            
            if skipInit
    if obj.link.IsConnected()
        try
            % LEER la configuración actual del hardware para que el objeto 
            % de MATLAB tenga los valores correctos de Sample Rate y Np.
            initStruct = obj.link.platform.board.Adrv9010Device.InitStructGet();
            
            obj.txSampleRate = double((initStruct.tx.txChannelCfg(1).profile.txInputRate_kHz)*1000);
            obj.rxSampleRate = double((initStruct.rx.rxChannelCfg(1).profile.rxOutputRate_kHz)*1000);
            obj.orxSampleRate = double((initStruct.rx.rxChannelCfg(5).profile.rxOutputRate_kHz)*1000);
            obj.DeframerNp = initStruct.dataInterface.deframer(1).jesd204Np;
            
            fprintf('--- Reconnected and Synchronized! ---\n');
            fprintf('Tx Rate: %.2f MHz, Np: %d\n', obj.txSampleRate/1e6, obj.DeframerNp);
        catch
            warning('Connected, but could not sync metadata. Using defaults.');
        end
    end
    return; % Salir aquí para no programar el chip
end

            if obj.link.IsConnected()
                
                adrv9010 = obj.link.Adrv9010Get(1);
                
                fprintf ('Programming Device\n');
                % obj.link.platform.board.Adrv9010Device.ConfigFileLoad(strcat('C:\\Program Files\\Analog Devices\\ADRV9025 Transceiver Evaluation Software_x64_FULL\\Resources\\Adi.Adrv9025.Profiles\\public\\ADRV9025Init_StdUseCase',int2str(obj.profile),'_nonLinkSharing.profile'));
                obj.link.platform.board.Adrv9010Device.ConfigFileLoad(strcat('C:\\Program Files\\Analog Devices\\ADRV9025 Transceiver Evaluation Software_x64_FULL\\Resources\\Adi.Adrv9025.Profiles\\public\\ADRV9025Init_StdUseCase',int2str(obj.profile),'_LinkSharing.profile'));

                initStruct = obj.link.platform.board.Adrv9010Device.InitStructGet();
                deviceClock_kHz = initStruct.clocks.deviceClock_kHz;
                
                % Retrieve tx Sample rate from the profile
                obj.txSampleRate = double((initStruct.tx.txChannelCfg(1).profile.txInputRate_kHz)*1000);
                fprintf ('Tx Sample Rate for this Profile is %d\n',obj.txSampleRate);
                
                % Retrieve rx Sample rate from the profile
                obj.rxSampleRate = double((initStruct.rx.rxChannelCfg(1).profile.rxOutputRate_kHz)*1000);
                fprintf ('Rx Sample Rate for this Profile is %d\n',obj.rxSampleRate);
                
                % Retrieve Orx Sample rate from the profile
                obj.orxSampleRate = double((initStruct.rx.rxChannelCfg(5).profile.rxOutputRate_kHz)*1000);
                fprintf ('ORx Sample Rate for this Profile is %d\n',obj.orxSampleRate);
                
                obj.DeframerNp = initStruct.dataInterface.deframer(1).jesd204Np;
                %fprintf ('Deframer Np is %d\n',obj.DeframerNp);
                
                initStruct.rx.rxInitChannelMask = 1023;
                initStruct.tx.txInitChannelMask = 15;
                
               
                
                % Force LO1 for Rx and LO2 for Tx/ORx
                if ~obj.aux_LO
                    initStruct.clocks.rx12LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO1;
                    initStruct.clocks.rx34LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO1;
                    initStruct.clocks.tx12LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO2;
                    initStruct.clocks.tx34LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO2;
                    initStruct.clocks.orx12LoSelect=  adrv9010_dll.Types.adi_adrv9010_OrxLoSel_e.ADI_ADRV9010_ORXLOSEL_TXLO;
                    initStruct.clocks.orx34LoSelect=  adrv9010_dll.Types.adi_adrv9010_OrxLoSel_e.ADI_ADRV9010_ORXLOSEL_TXLO;
                    initStruct.clocks.rfPll1LoMode = adrv9010_dll.Types.adi_adrv9010_PllLoMode_e.ADI_ADRV9010_INTLO_NOOUTPUT;
                    initStruct.clocks.rfPll2LoMode = adrv9010_dll.Types.adi_adrv9010_PllLoMode_e.ADI_ADRV9010_INTLO_NOOUTPUT;
                else
                    
                    initStruct.clocks.rx12LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO2;
                    initStruct.clocks.rx34LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO2;
                    initStruct.clocks.tx12LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO2;
                    initStruct.clocks.tx34LoSelect=  adrv9010_dll.Types.adi_adrv9010_LoSel_e.ADI_ADRV9010_LOSEL_LO2;
                    initStruct.clocks.orx12LoSelect=  adrv9010_dll.Types.adi_adrv9010_OrxLoSel_e.ADI_ADRV9010_ORXLOSEL_AUXLO;
                    initStruct.clocks.orx34LoSelect=  adrv9010_dll.Types.adi_adrv9010_OrxLoSel_e.ADI_ADRV9010_ORXLOSEL_AUXLO;
                    initStruct.clocks.rfPll1LoMode = adrv9010_dll.Types.adi_adrv9010_PllLoMode_e.ADI_ADRV9010_INTLO_NOOUTPUT;
                    initStruct.clocks.rfPll2LoMode = adrv9010_dll.Types.adi_adrv9010_PllLoMode_e.ADI_ADRV9010_INTLO_NOOUTPUT;
                end
                
                
                
                
                
                postMcsInit = adrv9010_dll.Types.adi_adrv9010_PostMcsInit_t();
                
                if ~obj.aux_LO
                    postMcsInit.radioCtrlInit.lo1PllFreq_Hz = txlo*1e6;
                    postMcsInit.radioCtrlInit.lo2PllFreq_Hz = txlo*1e6;
                    postMcsInit.radioCtrlInit.auxPllFreq_Hz = 0;
                else
                    
                    postMcsInit.radioCtrlInit.lo1PllFreq_Hz = 0;
                    postMcsInit.radioCtrlInit.lo2PllFreq_Hz = txlo*1e6;
                    postMcsInit.radioCtrlInit.auxPllFreq_Hz = txlo*1e6+(obj.aux_LO);
                end
                
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.rxRadioCtrlModeCfg.rxChannelMask = 31;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.rxRadioCtrlModeCfg.rxEnableMode = adrv9010_dll.Types.adi_adrv9010_RxEnableMode_e.ADI_ADRV9010_RX_EN_SPI_MODE;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.txRadioCtrlModeCfg.txChannelMask = double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TXALL);
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.txRadioCtrlModeCfg.txEnableMode = adrv9010_dll.Types.adi_adrv9010_TxEnableMode_e.ADI_ADRV9010_TX_EN_SPI_MODE;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.orxRadioCtrlModeCfg.orxEnableMode = adrv9010_dll.Types.adi_adrv9010_ORxEnableMode_e.ADI_ADRV9010_ORX_EN_SPI_MODE;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.orxRadioCtrlModeCfg.orxPinSelectSettlingDelay_armClkCycles = 0;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.orxRadioCtrlModeCfg.singleChannel1PinModeOrxSel = adrv9010_dll.Types.adi_adrv9010_SingleChannelPinModeOrxSel_e.ADI_ADRV9010_SINGLE_CH_PIN_MODE_ORX1_FE;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.orxRadioCtrlModeCfg.singleChannel2PinModeHighOrxSel = adrv9010_dll.Types.adi_adrv9010_SingleChannelPinModeOrxSel_e.ADI_ADRV9010_SINGLE_CH_PIN_MODE_ORX1_FE;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.orxRadioCtrlModeCfg.singleChannel1PinModeOrxSel = adrv9010_dll.Types.adi_adrv9010_SingleChannelPinModeOrxSel_e.ADI_ADRV9010_SINGLE_CH_PIN_MODE_ORX1_FE;
                postMcsInit.radioCtrlInit.radioCtrlModeCfg.orxRadioCtrlModeCfg.dualChannel2PinModeOrxSel = adrv9010_dll.Types.adi_adrv9010_DualChannelPinModeOrxSel_e.ADI_ADRV9010_DUAL_CH_PIN_MODE_ORX1_ORX3_SEL;
                
                postMcsInit.radioCtrlInit.txToOrxMapping.orx1Map = adrv9010_dll.Types.adi_adrv9010_TxToOrx1Mapping_e.ADI_ADRV9010_MAP_TX1_ORX1;
                postMcsInit.radioCtrlInit.txToOrxMapping.orx2Map = adrv9010_dll.Types.adi_adrv9010_TxToOrx2Mapping_e.ADI_ADRV9010_MAP_TX2_ORX2;
                postMcsInit.radioCtrlInit.txToOrxMapping.orx3Map = adrv9010_dll.Types.adi_adrv9010_TxToOrx3Mapping_e.ADI_ADRV9010_MAP_TX3_ORX3;
                postMcsInit.radioCtrlInit.txToOrxMapping.orx4Map = adrv9010_dll.Types.adi_adrv9010_TxToOrx4Mapping_e.ADI_ADRV9010_MAP_TX4_ORX4;
                
                
                % Setup the Init Cal Mask:
                
                postMcsInit.initCals.calMask = double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_BB_FILTER);
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_ADC_TUNER));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_RX_TIA));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_ORX_TIA));
                
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_LBRX_TIA));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_RX_DC_OFFSET));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_ORX_DC_OFFSET));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_LBRX_DC_OFFSET));
                
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_FLASH_CAL));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_INTERNAL_PATH_DELAY));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_LO_LEAKAGE_INTERNAL));
                %postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_LO_LEAKAGE_EXTERNAL));
                
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_QEC_INIT));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_LOOPBACK_RX_LO_DELAY));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_LOOPBACK_RX_RX_QEC_INIT));
                %postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_RX_LO_DELAY));
                
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_RX_QEC_INIT));
                %postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_ORX_LO_DELAY));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_ORX_QEC_INIT));
                postMcsInit.initCals.calMask = bitor(postMcsInit.initCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_DAC));
                
                %fprintf ('CalMask is %d\n',postMcsInit.initCals.calMask);
                postMcsInit.initCals.channelMask = 15;
                postMcsInit.initCals.warmBoot = 0;
                
                % Stream GPIO inputs init
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput0  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput1  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput2  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput3  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput4  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput5  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput6  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput7  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput8  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput9  = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput10 = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput11 = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput12 = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput13 = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput14 = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                postMcsInit.radioCtrlInit.streamGpioCfg.streamGpInput15 = adrv9010_dll.Types.adi_adrv9010_GpioPinSel_e.ADI_ADRV9010_GPIO_INVALID;
                
                obj.link.platform.board.Adrv9010Device.UtilityInitStructSet(postMcsInit);
                obj.link.platform.board.Adrv9010Device.ConfigFileLoad();
                
                obj.link.platform.board.ClockConfig(deviceClock_kHz, 122880, refClock, deviceClock_kHz);
                
                % Program the Part
                obj.link.platform.board.Program();
                
                %Now Run the Tx QEC Init
                obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(0, initStruct.tx.txInitChannelMask);
                
                %Wait 3 seconds before running Tx QEC init cals
                pause(3);
                
                if ((initStruct.tx.txInitChannelMask & 1) == 1)
                    fprintf ('Run Tx QEC Init For Channel 1 \n');
                    obj.TxQecInitRun(double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1));
                end
                
                if ((initStruct.tx.txInitChannelMask & 2) == 2)
                    fprintf ('Run Tx QEC Init For Channel 2 \n');
                    obj.TxQecInitRun(double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX2));
                end
                
                if ((initStruct.tx.txInitChannelMask & 4) == 4)
                    fprintf ('Run Tx QEC Init For Channel 3 \n');
                    obj.TxQecInitRun(double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX3));
                end
                
                if ((initStruct.tx.txInitChannelMask & 8) == 8)
                    fprintf ('Run Tx QEC Init For Channel 4 \n');
                    obj.TxQecInitRun(double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX4));
                end
                
                obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(0,0);
                
                % Set Tx Atten
                if ((initStruct.tx.txInitChannelMask & 1) == 1)
                    fprintf ('Set Tx Atten For Channel 1 \n');
                    obj.TxAttenSet(0, double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1));
                end
                
                if ((initStruct.tx.txInitChannelMask & 2) == 2)
                    fprintf ('Set Tx Atten For Channel 2 \n');
                    obj.TxAttenSet(0, double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX2));
                end
                
                if ((initStruct.tx.txInitChannelMask & 4) == 4)
                    fprintf ('Set Tx Atten For Channel 3 \n');
                    obj.TxAttenSet(0, double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX3));
                end
                
                if ((initStruct.tx.txInitChannelMask & 8) == 8)
                    fprintf ('Set Tx Atten For Channel 4 \n');
                    obj.TxAttenSet(1000, double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX4));
                end
                
                % Set Rx Gain
                if ((initStruct.rx.rxInitChannelMask & 1) == 1)
                    fprintf ('Set Rx Gain For Channel 1 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX1));
                end
                
                if ((initStruct.rx.rxInitChannelMask & 2) == 2)
                    fprintf ('Set Rx Gain For Channel 2 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX2));
                end
                
                if ((initStruct.rx.rxInitChannelMask & 4) == 4)
                    fprintf ('Set Rx Gain For Channel 3 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX3));
                end
                
                if ((initStruct.rx.rxInitChannelMask & 8) == 8)
                    fprintf ('Set Rx Gain For Channel 4 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX4));
                end
                
                % Set ObsRx Gain
                
                if ((initStruct.rx.rxInitChannelMask & 16) == 16)
                    fprintf ('Set ObsRx Gain For Channel 1 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX1));
                end
                
                if ((initStruct.rx.rxInitChannelMask & 32) == 32)
                    fprintf ('Set ObsRx Gain For Channel 2 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX2));
                end
                
                if ((initStruct.rx.rxInitChannelMask & 64) == 64)
                    fprintf ('Set ObsRx Gain For Channel 3 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX3));
                end
                
                if ((initStruct.rx.rxInitChannelMask & 128) == 128)
                    fprintf ('Set ObsRx Gain For Channel 4 \n');
                    obj.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX4));
                end
                
                fprintf ('Readback PLL \n');
                [a, lo1] = adrv9010.RadioCtrl.PllFrequencyGet(adrv9010_dll.Types.adi_adrv9010_PllName_e.ADI_ADRV9010_LO1_PLL, 0);
                fprintf ('LO1 set to : %d \n', lo1);
                [b, lo2] = adrv9010.RadioCtrl.PllFrequencyGet(adrv9010_dll.Types.adi_adrv9010_PllName_e.ADI_ADRV9010_LO2_PLL, 0);
                fprintf ('LO2 set to : %d \n',lo2);
                [b, aux] = adrv9010.RadioCtrl.PllFrequencyGet(adrv9010_dll.Types.adi_adrv9010_PllName_e.ADI_ADRV9010_AUX_PLL, 0);
                fprintf ('Aux_LO set to : %d \n',aux);
                fprintf ('Finished Programming Device\n');
                
            else
                fprintf ('Not Connected\n');
            end
        end
        
        function transmit(obj, txData, triggerName)
            if ~exist('triggerName', 'var')
                triggerName = 'IMMEDIATE';
            end
            
            txChannel=double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1);
            txData = reshape(txData, 1, []);
            txDataScaled = round(txData.*2^(double(obj.DeframerNp)-1 )); % round(txData.*2^15);
            row = size(txDataScaled, 1);

            if row == 1 %load a single test vector
                I = real(txDataScaled);
                Q = imag(txDataScaled);
                txData=zeros(8,length(I));
                if (txChannel == 2^0)
                    txData(1,:)= Q;
                    txData(2,:)= I;
                elseif (txChannel == 2^1)
                    txData(3,:)= Q;
                    txData(4,:)= I;
                elseif (txChannel == 2^2)
                    txData(5,:)= Q;
                    txData(6,:)= I;
                else
                    txData(7,:)= Q;
                    txData(8,:)= I;
                end

            else % dynamics scenario, load up to 4 test vectors
                txData=txDataScaled;
            end

            switch triggerName
                case 'IMMEDIATE'
                    txTrigger = adrv9010_dll.FpgaTypes.adi_fpga9010_TxTollgateTrigSources_e.ADI_FPGA9010_TX_IMM_TRIG;
                case 'TDD_SM'
                    txTrigger = adrv9010_dll.FpgaTypes.adi_fpga9010_TxTollgateTrigSources_e.ADI_FPGA9010_TX_TDD_SM;
            end

            % Create Array of .NET Objects
            I_TX1 = NET.convertArray(txData(1,:),'System.Int32');
            Q_TX1 = NET.convertArray(txData(2,:),'System.Int32');
            I_TX2 = NET.convertArray(txData(3,:),'System.Int32');
            Q_TX2 = NET.convertArray(txData(4,:),'System.Int32');
            I_TX3 = NET.convertArray(txData(5,:),'System.Int32');
            Q_TX3 = NET.convertArray(txData(6,:),'System.Int32');
            I_TX4 = NET.convertArray(txData(7,:),'System.Int32');
            Q_TX4 = NET.convertArray(txData(8,:),'System.Int32');
            IQ_TX_Array = NET.createGeneric('System.Collections.Generic.List',{'System.Int32[]'},I_TX1.Length);

            % Pass on IQ data to the .NET array
            IQ_TX_Array.Add(Q_TX1);
            IQ_TX_Array.Add(I_TX1);

            IQ_TX_Array.Add(Q_TX2);
            IQ_TX_Array.Add(I_TX2);

            IQ_TX_Array.Add(Q_TX3);
            IQ_TX_Array.Add(I_TX3);

            IQ_TX_Array.Add(Q_TX4);
            IQ_TX_Array.Add(I_TX4);

            % Transmit data
            obj.link.platform.board.PerformTx(txTrigger, IQ_TX_Array, 255);
        end

        % Disconnects the Platform
        function disconnect(obj)
            
            obj.link.platform.board.Client.Disconnect();
            fprintf ('Disconnected\n');
        end
        
        
        % Enable/Disable Tx/Rx and ORx channel Globally.
        % Configures Orx1/2 and Orx3/4
        
        function SetRxTxChannels(obj)
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(obj.SelRxChannels,obj.SelTxChannels);
            
            ORx1Enable = bitget(obj.SelRxChannels,5);
            ORx2Enable = bitget(obj.SelRxChannels,6);
            ORx3Enable = bitget(obj.SelRxChannels,7);
            ORx4Enable = bitget(obj.SelRxChannels,8);
            
            
            if (( ORx1Enable | ORx2Enable) == 1)
                fprintf ('ORx1/2 Selected\n');
                if (obj.use_adrvtrx_dll == 1)
                    %Framer crossbar setting for adrvtrx_dll temporarily commented out                  
                else
                    framer1XBar     = NET.createArray('adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarCfgX_t',1);
                    framer1XBar(1)=adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarCfg_t();
                    %framer1XBarGet = obj.link.platform.board.Adrv9010Device.DataInterface.AdcSampleXbarGet(adrv9010_dll.Types.adi_adrv9010_FramerSel_e.ADI_ADRV9010_FRAMER_1, framer1XBar(1));
                    framer1XBar(1).conv0 = adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarSel_e.ADI_ADRV9010_ADC_ORX1_I;
                    framer1XBar(1).conv1 = adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarSel_e.ADI_ADRV9010_ADC_ORX1_Q;                
                    obj.link.platform.board.Adrv9010Device.DataInterface.AdcSampleXbarSet(adrv9010_dll.Types.adi_adrv9010_FramerSel_e.ADI_ADRV9010_FRAMER_1, framer1XBar(1));
                end
            elseif (( ORx3Enable | ORx4Enable) == 1)
                fprintf ('ORx3/4 Selected\n');
                if (obj.use_adrvtrx_dll == 1)
                    %Framer crossbar setting for adrvtrx_dll temporarily commented out
                else
                    framer1XBar     = NET.createArray('adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarCfg_t',1);
                    framer1XBar(1)=adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarCfg_t();
                    %framer1XBarGet = obj.link.platform.board.Adrv9010Device.DataInterface.AdcSampleXbarGet(adrv9010_dll.Types.adi_adrv9010_FramerSel_e.ADI_ADRV9010_FRAMER_1, framer1XBar(1));
                    framer1XBar(1).conv0 = adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarSel_e.ADI_ADRV9010_ADC_ORX2_I;
                    framer1XBar(1).conv1 = adrv9010_dll.Types.adi_adrv9010_AdcSampleXbarSel_e.ADI_ADRV9010_ADC_ORX2_Q;
                    obj.link.platform.board.Adrv9010Device.DataInterface.AdcSampleXbarSet(adrv9010_dll.Types.adi_adrv9010_FramerSel_e.ADI_ADRV9010_FRAMER_1, framer1XBar(1));
                end
            end
            
        end
        
        % Generate TX Tone:
        % Inputs:		frequency: frequency of tone required in Hz
        %               dBFS: attenuation of tone in dB prior to transmission
        %                   across JESD link
        function [complexIQ] = ToneGen(obj, frequency, dBFs)
            
            format long
            
            sPerCycle = obj.txSampleRate/frequency; %calculate number of samples per cycle at sampling rate
            cyclesInBuffer = round(obj.bufferSize/sPerCycle); %calculate the number of cycles for closest frequency
            %that can fit in the buffer for perfect wrapping
            
            sPerCycleInt = obj.bufferSize/cyclesInBuffer; %calultate the new number of samples per cycle for new frequency
            newFreq = obj.txSampleRate/sPerCycleInt; %closest frequency to desired frequency that will fit buffer for perfect wrapping
            disp(['Tone Frequency = ' num2str(newFreq)]);
            stepRad = (2*pi)/sPerCycleInt; %calculate the step in radians between each sample
            samples = 0:1:obj.bufferSize-1;
            fullScale= double(2^(int32(obj.DeframerNp)-1)-4)*10^(dBFs/20); %calulate amplitude of tone
            
            I = fullScale*sin(double(stepRad)*samples); %I samples
            %I = round(I/4)*4;   %I samples dropping off the first two LSBs
            I = I./2^15; % normalize I to be in line with modulated test vectors
            
            Q = fullScale*-cos(double(stepRad)*samples); %Q samples
            %Q = round(Q/4)*4; %Q samples dropping off teh first two LSBs
            Q = Q./2^15; % normalize Q to be in line with modulated test vectors
            
            complexIQ=complex(I,Q);
            
            %Write IQ data to a text file
            %fileID = fopen('exp1.txt','w');
            %fprintf(fileID,'%d\t%d\n',[I;Q]);
            %fclose(fileID);
        end
        
        
        
        % Transmits data from FPGA to platform
        % Inputs:
        %               selTxChannel: Select Tx Channel using four bits:
        %                             0001 for TX1, i.e. 1
        %                             0010 for TX2, i.e. 2
        %                             0100 for TX3, i.e. 4
        %                             1000 for TX4, i.e. 8
        %                             1111 (Enable all 4 TX) i.e. 15
        %               txData: Array of I,Q vectors in the following
        %               order: Tx1_I, Tx1_Q, Tx2_I, Tx2Q, Tx3_I, Tx3_Q,
        %               Tx4_I, Tx4_Q.
        %               triggerName: Trigger on which to transmit Tx data
        
        function TransmitData(obj, channels, txData, triggerName)
            
            % Enable TX Channels based on selTxChannel input value
            obj.SelTxChannels = channels;
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(obj.SelRxChannels,obj.SelTxChannels);
            
            txDataScaled=round(txData.*2^15);
            
            [row col] = size(txDataScaled);
            
            if row == 1 %load a single test vector
                
                I = real(txDataScaled);
                Q = imag(txDataScaled);
                
                txData=zeros(8,length(I));
                
                if (channels==2^0)
                    txData(1,:)=Q;
                    txData(2,:)=I;
                elseif (channels==2^1)
                    txData(3,:)=Q;
                    txData(4,:)=I;
                elseif (channels==2^2)
                    txData(5,:)=Q;
                    txData(6,:)=I;
                else
                    txData(7,:)=Q;
                    txData(8,:)=I;
                end
                
            else % dynamics scenario, load up to 4 test vectors
                txData=txDataScaled;

            end
            
            switch triggerName
                case 'IMMEDIATE'
                    txTrigger = adrv9010_dll.FpgaTypes.adi_fpga9010_TxTollgateTrigSources_e.ADI_FPGA9010_TX_IMM_TRIG;
                case 'TDD_SM'
                    txTrigger = adrv9010_dll.FpgaTypes.adi_fpga9010_TxTollgateTrigSources_e.ADI_FPGA9010_TX_TDD_SM;
            end
            
            
            % Create Array of .NET Objects
            I_TX1 = NET.convertArray(txData(1,:),'System.Int32');
            Q_TX1 = NET.convertArray(txData(2,:),'System.Int32');
            I_TX2 = NET.convertArray(txData(3,:),'System.Int32');
            Q_TX2 = NET.convertArray(txData(4,:),'System.Int32');
            I_TX3 = NET.convertArray(txData(5,:),'System.Int32');
            Q_TX3 = NET.convertArray(txData(6,:),'System.Int32');
            I_TX4 = NET.convertArray(txData(7,:),'System.Int32');
            Q_TX4 = NET.convertArray(txData(8,:),'System.Int32');
            IQ_TX_Array = NET.createGeneric('System.Collections.Generic.List',{'System.Int32[]'},I_TX1.Length);
            
            
            % Pass on IQ data to the .NET array
            IQ_TX_Array.Add(Q_TX1);
            IQ_TX_Array.Add(I_TX1);
            
            IQ_TX_Array.Add(Q_TX2);
            IQ_TX_Array.Add(I_TX2);
            
            IQ_TX_Array.Add(Q_TX3);
            IQ_TX_Array.Add(I_TX3);
            
            IQ_TX_Array.Add(Q_TX4);
            IQ_TX_Array.Add(I_TX4);
            
            % Transmit data
            obj.link.platform.board.PerformTx(txTrigger, IQ_TX_Array, 255);
        end
        
        
        % % Read in IQ data from a file
        % % Inputs:
        % % 		dataFile: String defining the datapath of the file to be read.
        % % 		File should be tab delimited, I \t Q \n format
        % % Outputs:
        % % 		I: The I datapoints from the file
        % %
        % %		Q: The Q datapoints from the file
        % function [I,Q] = ReadFileData(obj,dataFile)
        % 
        %     FID = fopen(dataFile);
        %     IQ = fscanf(FID,'%d');
        %     fclose(FID);
        % 
        %     I = IQ(1:2:end);
        %     Q = IQ(2:2:end);
        % 
        % end
        
        % This function sets the attenuation of the transmit paths.
        % Inputs:
        % 		txAtten_mdB: Attenuation value in mdB (i.e. 1dB = 1000)
        % 		channelMask: Enumerated type of the channel on which to change
        % 					 attenuation.
        function TxAttenSet(obj, txAtten_mdB, channelMask)
            
            adrv9010TxAtten      = NET.createArray('adrv9010_dll.Types.adi_adrv9010_TxAtten_t',1);
            adrv9010TxAtten(1)   = adrv9010_dll.Types.adi_adrv9010_TxAtten_t();
            adrv9010TxAtten(1).txAttenuation_mdB    = txAtten_mdB;
            adrv9010TxAtten(1).txChannelMask   = channelMask;
            
            obj.link.platform.board.Adrv9010Device.Tx.TxAttenSet(adrv9010TxAtten, 1);
        end
        
        function orxData = capture(obj, channels, captureTime, triggerName)
            %       rxData: Captured Rx/ORx data. Individual vectors stored in the
            %       following order:
            %       0: Rx1_I, 1: Rx1_Q, 2: Rx2_I, 3: Rx2_Q, 4: Rx3_I,
            %       5: Rx3_Q, 6: Rx4_I, 7: Rx4_Q, 8: ORx1_I, 9: ORx1_Q
            
            obj.SelRxChannels = channels;
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(obj.SelRxChannels,obj.SelTxChannels);
            switch triggerName
                case 'IMMEDIATE'
                    rxTrigger = adrv9010_dll.FpgaTypes.adi_fpga9010_RxTollgateTrigSources_e.ADI_FPGA9010_IMM_TRIG;
                case 'TDD_SM'
                    rxTrigger = adrv9010_dll.FpgaTypes.adi_fpga9010_RxTollgateTrigSources_e.ADI_FPGA9010_TDD_SM;
            end
            rxData2 = obj.link.platform.board.PerformRx(rxTrigger,255, captureTime, 1000);
            rxData = obj.link.platform.board.ScaleRx(rxData2);
            
            I_ORX1 = double(rxData.Item(8));
            Q_ORX1 = double(rxData.Item(9));
            
            orxData = I_ORX1 + 1j*Q_ORX1;
            
            
            freq_shift = exp(1i*2*pi*(1:length(orxData))*obj.aux_LO/491.52e6);
            orxData = orxData .* freq_shift;
            
        end
        
        % This function sets the gain of the Rx paths
        % Inputs:
        % 	gainIndex: The index of the gain table to be selected (permissable
        % 				values 255 to 195)
        % 	channelMask: Enumerated type of the channel to change the gain of.
        % Example: To set the gain of any of the RX Paths
        %   tok.RxGainSet(251, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX1));
        % 	tok.RxGainSet(251, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX2));
        % 	tok.RxGainSet(255, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX3));
        % 	tok.RxGainSet(251, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX4));
        
        function RxGainSet(obj, gainIndex, channelMask)
            
            adrv9010RxGain      = NET.createArray('adrv9010_dll.Types.adi_adrv9010_RxGain_t',1);
            adrv9010RxGain(1)   = adrv9010_dll.Types.adi_adrv9010_RxGain_t();
            adrv9010RxGain(1).gainIndex       = gainIndex;
            adrv9010RxGain(1).rxChannelMask   = channelMask;
            
            obj.link.platform.board.Adrv9010Device.Rx.RxGainSet(adrv9010RxGain, 1);
        end
        
        % This function gets the gain of the Rx paths
        % Inputs:
        % 	channelMask: Enumerated type of the channel to change the gain of.
        % Outputs:
        %   rxGain: Decimal value (Max 255 and Min 195)
        % Example: To set the gain of any of the RX Paths
        %   rxGain = tok.RxGainGet(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX1);
        % 	rxGain = tok.RxGainGet(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX2);
        % 	rxGain = tok.RxGainGet(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX3);
        % 	rxGain = tok.RxGainGet(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RX4);
        
        function rxGain = RxGainGet(obj, channelMask)
            
            adrv9010RxGain =adrv9010_dll.Types.adi_adrv9010_RxGain_t();
            [a, b] = obj.link.platform.board.Adrv9010Device.Rx.RxGainGet(channelMask, adrv9010RxGain);
            rxGain = b.gainIndex;
            fprintf ('Rx Gain is : %d \n', rxGain);
        end
        
        % This function sets the gain of the ORx paths
        % Inputs:
        % 	gainIndex: The index of the gain table to be selected (permissable
        % 				values 255 to 195)
        % 	channelMask: Enumerated type of the channel to change the gain of.
        % Example: To set the gain of the ORX1 Path.
        %   tok.OrxGainSet(200, double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX1));
        
        function OrxGainSet(obj, gainIndex, channelMask)
            
            adrv9010OrxGain      = NET.createArray('adrv9010_dll.Types.adi_adrv9010_RxGain_t',1);
            adrv9010OrxGain(1)   = adrv9010_dll.Types.adi_adrv9010_RxGain_t();
            adrv9010OrxGain(1).gainIndex       = gainIndex;
            adrv9010OrxGain(1).rxChannelMask   = channelMask;
            
            obj.link.platform.board.Adrv9010Device.Rx.RxGainSet(adrv9010OrxGain, 1);
        end
        
        % This function gets the gain of the ORx paths
        % Inputs:
        % 	channelMask: Enumerated type of the channel to change the gain of.
        % Outputs:
        %   rxGain: Decimal value (Max 255 and Min 195)
        % Example:
        %   orxGain = tok.ORxGainGet(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX1);
        
        function orxGain = ORxGainGet(obj, channelMask)
            
            adrv9010ORxGain =adrv9010_dll.Types.adi_adrv9010_RxGain_t();
            [a, b] = obj.link.platform.board.Adrv9010Device.Rx.RxGainGet(channelMask, adrv9010ORxGain);
            orxGain = b.gainIndex;
            fprintf ('ORx Gain is : %d \n', orxGain);
        end
        
        
        % Plot the FFT using rxData
        % I and Q are obtained by running rxData function(Check in running script)
        % Inputs:
        %		I: I data for complex FFT
        %		Q: Q data for complex FFT
        %		Path: 0 if plotting Rx data, 1 if plotting ORx data
        % Output: FFT Plot
        
        
        % Set the PLL Frequencies for LO1 or LO2:
        % PLL frequencies for Tx and ORx are represented by enum LO1
        % PLL frequencies for Rx are represented by enum LO2
        % Inputs:
        %		pllName: string 'LO1' or 'LO2'
        %		pllFreq: Pll LO frequency in Hz.
        function PllFrequencySet(obj, pllName, pllFreq)
            
            if(strcmp(pllName,'LO1'))
                pllName = adrv9010_dll.Types.adi_adrv9010_PllName_e.ADI_ADRV9010_LO1_PLL;
            elseif(strcmp(pllName,'LO2'))
                pllName = adrv9010_dll.Types.adi_adrv9010_PllName_e.ADI_ADRV9010_LO2_PLL;
            elseif(strcmp(pllName,'AUX'))
                pllName = adrv9010_dll.Types.adi_adrv9010_PllName_e.ADI_ADRV9010_AUX_PLL;
            end
            
            adrv9010 = obj.link.Adrv9010Get(1);
            obj.link.platform.board.Adrv9010Device.RadioCtrl.PllFrequencySet(pllName, pllFreq);
            [a, lo] = adrv9010.RadioCtrl.PllFrequencyGet(pllName, 0);
            fprintf ('%s LO set to : %d \n', char(pllName), lo);            
        end
        
        % Get the Status of PLL.
        % The 1 MSB tells if PLL is locked (When High)
        % [D4]: SERDES PLL
        % [D3]: AUX PLL
        % [D2]: LO2
        % [D1]: LO1
        % [D0]: CLK PLL
        function PllStatusGet(obj)
            
            c = 0;
            adrv9010 = obj.link.Adrv9010Get(1);
            
            [a, b]=adrv9010.Hal.SpiByteRead(hex2dec('6847'),0);
            
            % Convert decimal data on 'b' into binary data on bin1
            bin1 = dec2bin(b);
            
            % Get Pll Status
            [a, c] = adrv9010.RadioCtrl.PllStatusGet(c);
            
            % Convert decimal data on 'c' into binary data on bin2
            bin2 = dec2bin(c);
            
            % Concatenate {bin1(bit0),bin2}. The first bit of Bin1 should be
            % MSB.
            concat   = strcat(bin1(1),bin2);
            fprintf ('PLL Status is : %d \n', bin2dec(concat));
            
        end
        
        % This function configures Automatic Gain Control
        
        function RxAgcConfSet(obj)
            
            % Create an instance of the agcConfig class
            agcConfig = adrv9010_dll.Types.adi_adrv9010_AgcCfg_t();
            
            % General AGC Configuration
            agcConfig.rxChannelMask = 15;
            agcConfig.agcPeakWaitTime = 4;
            agcConfig.agcRxMaxGainIndex = 255;
            agcConfig.agcRxMinGainIndex = 195;
            agcConfig.agcGainUpdateCounter = 921600;
            agcConfig.agcRxAttackDelay = 10;
            agcConfig.agcSlowLoopSettlingDelay = 16;
            agcConfig.agcLowThreshPreventGainInc = 1;
            agcConfig.agcChangeGainIfThreshHigh = 1;
            agcConfig.agcPeakThreshGainControlMode= 1;
            agcConfig.agcResetOnRxon = 0;
            agcConfig.agcEnableSyncPulseForGainCounter = 0;
            agcConfig.agcEnableFastRecoveryLoop = 0;
            
            % adi_adrv9010_AgcPeak_t agcPeak;
            agcConfig.agcPeak.agcUnderRangeLowInterval = 205000/245;
            agcConfig.agcPeak.agcUnderRangeMidInterval = 2;
            agcConfig.agcPeak.agcUnderRangeHighInterval = 4;
            agcConfig.agcPeak.apdHighThresh = 60;
            agcConfig.agcPeak.apdLowThresh = 25;
            agcConfig.agcPeak.apdUpperThreshPeakExceededCnt = 10;
            agcConfig.agcPeak.apdLowerThreshPeakExceededCnt = 3;
            agcConfig.agcPeak.enableHb2Overload = 1;
            agcConfig.agcPeak.hb2OverloadDurationCnt = 1;
            agcConfig.agcPeak.hb2OverloadThreshCnt = 1;
            agcConfig.agcPeak.hb2HighThresh = 11598; %-3dBFS
            agcConfig.agcPeak.hb2UnderRangeLowThresh = 8211;
            agcConfig.agcPeak.hb2UnderRangeMidThresh = 5813;
            agcConfig.agcPeak.hb2UnderRangeHighThresh = 2913;
            agcConfig.agcPeak.hb2UpperThreshPeakExceededCnt = 10;
            agcConfig.agcPeak.hb2UnderRangeHighThreshExceededCnt = 3;
            agcConfig.agcPeak.hb2UnderRangeMidThreshExceededCnt = 3;
            agcConfig.agcPeak.hb2UnderRangeLowThreshExceededCnt = 3;
            agcConfig.agcPeak.hb2OverloadPowerMode = 0;
            agcConfig.agcPeak.hb2ThreshConfig = 3;
            
            agcConfig.agcPeak.apdGainStepAttack = 4;
            agcConfig.agcPeak.apdGainStepRecovery = 2;
            agcConfig.agcPeak.hb2GainStepAttack = 4;
            agcConfig.agcPeak.hb2GainStepHighRecovery =2;
            agcConfig.agcPeak.hb2GainStepMidRecovery = 4;
            agcConfig.agcPeak.hb2GainStepLowRecovery = 8;
            
            % adi_adrv9010_AgcPower_t agcPower;
            agcConfig.agcPower.powerEnableMeasurement = 0;
            agcConfig.agcPower.powerInputSelect = 0;
            agcConfig.agcPower.underRangeHighPowerThresh = 9;
            agcConfig.agcPower.underRangeLowPowerThresh = 2;
            agcConfig.agcPower.underRangeHighPowerGainStepRecovery = 0;
            agcConfig.agcPower.underRangeLowPowerGainStepRecovery = 0;
            agcConfig.agcPower.powerMeasurementDuration = 5;
            agcConfig.agcPower.rxTddPowerMeasDuration = 5;
            agcConfig.agcPower.rxTddPowerMeasDelay = 1;
            agcConfig.agcPower.overRangeHighPowerThresh = 2;
            agcConfig.agcPower.overRangeLowPowerThresh = 0;
            agcConfig.agcPower.powerLogShift = 1;  % Force to 1
            agcConfig.agcPower.overRangeHighPowerGainStepAttack = 0;
            agcConfig.agcPower.overRangeLowPowerGainStepAttack = 0;
            
            % Make agcConfig into array types (necessary for syntax reasons)
            agcConfigArr = NET.createArray('adrv9010_dll.Types.adi_adrv9010_AgcCfg_t',1);
            agcConfigArr(1) = agcConfig;
            
            % Write settings to device
            adrv9010 = obj.link.Adrv9010Get(1);
            adrv9010.Agc.AgcCfgSet(agcConfigArr, 1);
        end
        
        
        % This function selects the Rx Gain Mode i.e. AGC or MGC
        % Inputs:
        %       mode: Enumerated type of the class to select AGC or MGC
        % Example:
        %    This would select AGC mode
        %       tok.rxGainModeSel(adrv9010_dll.Types.adi_adrv9010_RxAgcMode_e.ADI_ADRV9010_AGCSLOW);
        %    This would select MGC mode
        %       tok.rxGainModeSel(adrv9010_dll.Types.adi_adrv9010_RxAgcMode_e.ADI_ADRV9010_MGC);
        
        function rxGainModeSel(obj,mode)
            
            % Create an instance of the rxGainMode class
            rxGainMode = adrv9010_dll.Types.adi_adrv9010_RxAgcMode_t();
            
            % General Rx Gain Mode Configuration
            rxGainMode.rxChannelMask = 15;
            rxGainMode.agcMode = mode;
            
            % Make rxGainMode into array types (necessary for syntax reasons)
            rxGainModeArr = NET.createArray('adrv9010_dll.Types.adi_adrv9010_RxAgcMode_t',1);
            rxGainModeArr(1) = rxGainMode;
            
            % Enable AGC Mode
            adrv9010 = obj.link.Adrv9010Get(1);
            adrv9010.Rx.RxGainCtrlModeSet(rxGainModeArr, 1);
        end
        
        % This function enables tracking calibrations
        % Inputs:
        %       trackingCalMask: Mask composed of the following bits (set
        %       to 1 to enable)
        %           [D0] = Rx1QEC Tracking Calibration
        %           [D1] = Rx2QEC Tracking Calibration
        %           [D2] = Rx3QEC Tracking Calibration
        %           [D3] = Rx4QEC Tracking Calibration
        %           [D4] = ORx1QEC Tracking Calibration
        %           [D5] = ORx2QEC Tracking Calibration
        %           [D6] = ORx3QEC Tracking Calibration
        %           [D7] = ORx4QEC Tracking Calibration
        %           [D8] = Tx1LOL Tracking Calibration
        %           [D9] = Tx2LOL Tracking Calibration
        %           [D10] = Tx3LOL Tracking Calibration
        %           [D11] = Tx4LOL Tracking Calibration
        %           [D12] = Tx1QEC Tracking Calibration
        %           [D13] = Tx2QEC Tracking Calibration
        %           [D14] = Tx3QEC Tracking Calibration
        %           [D15] = Tx4QEC Tracking Calibration
        
        %           Example: 15 would enable Rx1/Rx2/Rx3/Rx4 QEC
        %       enableDisableFlag: Enum to enable or disable Calibrations
        %           adi_adrv9010_TrackingCalEnableDisable_e.ADI_ADRV9010_TRACKING_CAL_ENABLE
        %           adi_adrv9010_TrackingCalEnableDisable_e.ADI_ADRV9010_TRACKING_CAL_DISABLE
        
        function TrackingCalsSet(obj,trackingCalMask, enableDisableFlag)
            obj.link.platform.board.Adrv9010Device.Cals.TrackingCalsEnableSet(trackingCalMask, enableDisableFlag);
        end
        
        % This function performs QEC initialization for the TX channels
        % Inputs:
        %       txChannel: Enums to select from TX1/2/3/4
        % Example for TX1:
        %       TxQecInitRun(double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1));
        
        function TxQecInitRun(obj, txChannel)
            
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableGet(double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RXOFF), double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TXOFF));
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RXOFF), txChannel);
            
            txCals = NET.createArray('adrv9010_dll.Types.adi_adrv9010_InitCals_t',0);
            txCals = adrv9010_dll.Types.adi_adrv9010_InitCals_t();
            txCals.calMask = double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_QEC_INIT);
            txCals.calMask = bitor(txCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_INTERNAL_PATH_DELAY));
            txCals.calMask = bitor(txCals.calMask, double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_LOOPBACK_RX_LO_DELAY));
            fprintf ('Cal Mask: %d \n',txCals.calMask);
            txCals.channelMask = int32(txChannel);
            
            %fprintf ('txChannel: %d \n',int32(txChannel));
            txCals.warmBoot = 0;
            obj.link.platform.board.Adrv9010Device.Cals.InitCalsRun(txCals);
            % wait for 1 sec (1000), 0 is errorflag
            obj.link.platform.board.Adrv9010Device.Cals.InitCalsWait(1000, 0);
            fprintf ('Tx QEC Init Running\n');
            
        end
        
        % This function performs External LOL Initialization for the TX channels
        % Inputs:
        %       txChannel: Enum for Tx1
        % Example for TX1:
        %		TxExtLOLInitRun(double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1));
        
        function TxExtLOLInitRun (obj, txChannel)
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableGet(double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RXOFF), double(adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TXOFF));
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(double(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_RXOFF), txChannel);
            
            txCals = NET.createArray('adrv9010_dll.Types.adi_adrv9010_InitCals_t',0);
            txCals = adrv9010_dll.Types.adi_adrv9010_InitCals_t();
            txCals.calMask = double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_LO_LEAKAGE_EXTERNAL);
            
            %fprintf ('Cal Mask: %d \n',txCals.calMask);
            txCals.channelMask = int32(txChannel);
            txCals.warmBoot = 0;
            
            obj.link.platform.board.Adrv9010Device.Cals.InitCalsRun(txCals);
            % wait for 1 sec (1000), 0 is errorflag
            obj.link.platform.board.Adrv9010Device.Cals.InitCalsWait(1000, 0);
            fprintf ('Tx External LOL Init Running\n');
        end
             
        function [] = Lol_Qec_Cal_Enable(obj)
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(0,0);
            obj.link.platform.board.Adrv9010Device.RadioCtrl.TxToOrxMappingSet(adrv9010_dll.Types.adi_adrv9010_RxChannels_e.ADI_ADRV9010_ORX2,adrv9010_dll.Types.adi_adrv9010_TxChannels_e.ADI_ADRV9010_TX1);
            initStruct = obj.link.platform.board.Adrv9010Device.InitStructGet();
            initStruct.rx.rxInitChannelMask = hex2dec('31F');
            initStruct.tx.txInitChannelMask = hex2dec('F');
            errorFlag = 0;
            txCals = adrv9010_dll.Types.adi_adrv9010_InitCals_t();
            txCals.calMask = double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_LO_LEAKAGE_EXTERNAL) + double(adrv9010_dll.Types.adi_adrv9010_InitCalibrations_e.ADI_ADRV9010_TX_LO_LEAKAGE_INTERNAL);
            txCals.channelMask = 1;
            txCals.warmBoot = 0;
            obj.link.platform.board.Adrv9010Device.Cals.InitCalsRun(txCals);
            obj.link.platform.board.Adrv9010Device.Cals.InitCalsWait(2000, errorFlag);
            
            % Enable tracking cals
            %trackingCalMask = double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_TX1_LOL) + double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_TX1_QEC)+ double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_ORX2_QEC);
            trackingCalMask = double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_TX1_LOL) + double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_TX1_QEC);
            obj.link.platform.board.Adrv9010Device.Cals.TrackingCalsEnableSet((trackingCalMask), adrv9010_dll.Types.adi_adrv9010_TrackingCalEnableDisable_e.ADI_ADRV9010_TRACKING_CAL_ENABLE);
            obj.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(0,1);
        end
        
        function [] = Lol_Qec_Cal_Disable(obj)
            trackingCalMask = double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_TX1_LOL) + double(adrv9010_dll.Types.adi_adrv9010_TrackingCalibrations_e.ADI_ADRV9010_TRACK_TX1_QEC);
            obj.link.platform.board.Adrv9010Device.Cals.TrackingCalsEnableSet((trackingCalMask), adrv9010_dll.Types.adi_adrv9010_TrackingCalEnableDisable_e.ADI_ADRV9010_TRACKING_CAL_DISABLE);
        end

    end
    methods (Static)
    function obj = reconnect(txlo, profile, refClock)
        % RECONNECT Crea un objeto ADRV902x sin reprogramar el hardware
        % Uso: obj = ADRV902x.reconnect(2600); % 2.6GHz
        
        if nargin < 2
            profile = 14; % Perfil por defecto (ajustar según tu caso usual)
        end
        if nargin < 3
            refClock = 122880; % RefClock usual de 122.88 MHz
        end
        if nargin < 1
            error('Debes proporcionar al menos la frecuencia de LO (txlo).');
        end

        % Llamamos al constructor con skipInit = true (sexto argumento)
        % ADRV902x(profile, txlo, refClock, set_aux_LO, use_adrvtrx_dll, skipInit)
        obj = ADRV902x(profile, txlo, refClock, 0, 1, true);
        
        % Verificación final de seguridad
        if ~obj.link.IsConnected()
            error('No se pudo establecer conexión con la IP 192.168.1.10');
        end
    end
end
end
