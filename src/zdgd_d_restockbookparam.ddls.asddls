@EndUserText.label: 'ReStockBook action: Parameter'
define abstract entity ZDGD_D_ReStockBookParam

{
  @Consumption.valueHelpDefinition: [ { entity: { name: 'ZDGD_C_BookMasterData', element: 'BookID' },
                                        useForValidation: true } ]
  @Semantics.uuid: true
  BookID : sysuuid_x16;

  StockThreshold: abap.int1;
  TargetStock: abap.int1;
}
