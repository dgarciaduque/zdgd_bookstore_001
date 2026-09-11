@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Book'
@AbapCatalog.deliveryClass: #APPLICATION_DATA
@ClientHandling.type: #CLIENT_DEPENDENT
define table entity ZDGD_I_Book {
  key BookID     : sysuuid_x16;
  BookstoreID    : sysuuid_x16;
  BookName       : abap.char(50);
  Author         : abap.char(50);

  _Bookstore : association to parent ZDGD_I_BookStore on $projection.BookstoreID = _Bookstore.BookstoreID;
}
