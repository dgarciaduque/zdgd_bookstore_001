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

  @EndUserText.label: 'Book Name'
  BookName,

  @EndUserText.label: 'Author'
  Author,

      /* Associations */
      _Bookstore: redirected to parent ZDGD_C_Bookstore
}
