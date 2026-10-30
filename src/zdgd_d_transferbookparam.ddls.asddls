@EndUserText.label: 'Transfer Books: action parameter'
define root abstract entity ZDGD_D_TransferBookParam

{
      @UI.hidden: true
      @Semantics.uuid: true
  key ParameterID : sysuuid_x16;

      _TransferItems : composition [0..*] of ZDGD_D_TransferBookParamItem;
}
