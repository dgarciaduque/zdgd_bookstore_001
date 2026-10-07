@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Bookstore Books'

@Metadata.allowExtensions: true

define view entity ZDGD_C_Book
  as projection on ZDGD_I_Book

{
  key BookstoreID,
  key BookID,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZDGD_C_BookMasterData', element: 'BookName' },
                                            additionalBinding: [ { element: 'Author',
                                                                   localElement: 'Author',
                                                                   usage: #RESULT },
                                                                 { element: 'Language',
                                                                   localElement: 'Language',
                                                                   usage: #RESULT } ],
                                            useForValidation: true } ]
      BookName,

      Author,

      @EndUserText.label: 'Units in Stock'
      UnitsInStock,

      @EndUserText.label: 'Language'
      Language,

      /* Associations */
      _Bookstore: redirected to parent ZDGD_C_Bookstore
}
