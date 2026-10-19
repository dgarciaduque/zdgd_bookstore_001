@EndUserText.label: 'ReStockBook action: Parameter'
define abstract entity ZDGD_D_ReStockBookParam

{
  BookID : sysuuid_x16;
  StockThreshold: abap.int1;
  TargetStock: abap.int1;
}
