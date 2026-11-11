@EndUserText.label: 'Transfer Books: action parameter item'
define abstract entity ZDGD_D_TransferBookParamItem

{
      @Semantics.uuid: true
      @UI.hidden: true
  key ParameterID          : sysuuid_x16;

      @Semantics.uuid: true
      @UI.hidden: true
  key ItemID       : sysuuid_x16;

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZDGD_C_Bookstore', element: 'BookstoreID' },
                                            useForValidation: true } ]
      @EndUserText.label: 'Target Bookstore'
      @Semantics.uuid: true
      TargetBookstoreID      : sysuuid_x16;

      @EndUserText.label: 'Units to Transfer'
      UnitsToTransfer        : abap.int4;

      _TransferBook : association to parent ZDGD_D_TransferBookParam
          on $projection.ParameterID = _TransferBook.ParameterID;
}
