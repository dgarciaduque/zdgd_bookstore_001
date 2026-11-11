@EndUserText.label: 'TransferBook action parameter'
define abstract entity ZDGD_D_TransferSingleBookParam

{
  @Consumption.valueHelpDefinition: [ { entity: { name: 'ZDGD_C_Bookstore', element: 'BookstoreID' },
                                        useForValidation: true } ]
  @EndUserText.label: 'Target Bookstore'
  @Semantics.uuid: true
  TargetBookstoreID      : sysuuid_x16;

  @EndUserText.label: 'Units to Transfer'
  UnitsToTransfer        : abap.int4;
}
