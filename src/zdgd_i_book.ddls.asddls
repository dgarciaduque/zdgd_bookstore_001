@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Book'
@AbapCatalog.deliveryClass: #APPLICATION_DATA
@ClientHandling.type: #CLIENT_DEPENDENT
define table entity ZDGD_I_Book {
  key BookID     : sysuuid_x16;
  BookstoreID    : sysuuid_x16;
  BookName       : ZDGD_BookName;
  Author         : ZDGD_BookAuthor;

  _Bookstore : association to parent ZDGD_I_BookStore on $projection.BookstoreID = _Bookstore.BookstoreID;
}
