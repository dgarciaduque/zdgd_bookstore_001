@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Books'

@Metadata.allowExtensions: true

define view entity ZDGD_C_Book
  as projection on ZDGD_I_Book

{
      @EndUserText.label: 'Book ID'
  key BookID,

      @EndUserText.label: 'Bookstore ID'
      BookstoreID,

      BookName,
      Author,

      @EndUserText.label: 'Units in Stock'
      UnitsInStock,

      @EndUserText.label: 'Language'
      Language,

      /* Associations */
      _Bookstore: redirected to parent ZDGD_C_Bookstore
}
