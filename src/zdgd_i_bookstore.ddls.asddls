@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bookstore'
@AbapCatalog.deliveryClass: #APPLICATION_DATA
@ClientHandling.type: #CLIENT_DEPENDENT
define root table entity ZDGD_I_Bookstore {
  key BookstoreID    : sysuuid_x16;
  BookstoreName : abap.char(50);
  City          : abap.char(50);

  _Books : composition of many ZDGD_I_Book;
}
