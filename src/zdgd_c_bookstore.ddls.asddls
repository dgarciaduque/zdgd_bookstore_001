@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Bookstores'

define root view entity ZDGD_C_BOOKSTORE
  provider contract transactional_query
  as projection on ZDGD_I_Bookstore

{
  key BookstoreID,

      BookstoreName,
      City,

      /* Associations */
      _Books: redirected to composition child ZDGD_C_BOOK
}
