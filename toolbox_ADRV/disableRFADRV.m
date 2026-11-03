function disableRFADRV(TRx)
    TRx.link.platform.board.Adrv9010Device.RadioCtrl.RxTxEnableSet(0, 0);
end