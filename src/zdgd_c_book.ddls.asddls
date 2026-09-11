@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Books'

define view entity ZDGD_C_BOOK
  as projection on ZDGD_I_Book

{
  key BookID,

      BookstoreID,
      BookName,
      Author,

      /* Associations */
      _Bookstore: redirected to parent ZDGD_C_BOOKSTORE
}
