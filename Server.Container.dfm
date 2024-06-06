object ServerContainer: TServerContainer
  Height = 339
  Width = 519
  PixelsPerInch = 120
  object DSServer1: TDSServer
    Left = 352
    Top = 198
  end
  object DSServerClass1: TDSServerClass
    OnGetClass = DSServerClass1GetClass
    Server = DSServer1
    Left = 250
    Top = 14
  end
end
