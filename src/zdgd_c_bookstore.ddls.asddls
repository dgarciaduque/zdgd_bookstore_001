@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Bookstores'

@Metadata.allowExtensions: true

@Search.searchable: true

define root view entity ZDGD_C_Bookstore
  provider contract transactional_query
  as projection on ZDGD_I_Bookstore

{
      @EndUserText.label: 'Bookstore ID'
  key BookstoreID,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      BookstoreName,

      City,

      /* Associations */
      _Books: redirected to composition child ZDGD_C_Book
}
