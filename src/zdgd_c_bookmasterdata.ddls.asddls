@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Book Master Data'

@Metadata.allowExtensions: true

define root view entity ZDGD_C_BookMasterData
  provider contract transactional_query
  as projection on ZDGD_I_BookMasterData

{
  key BookID,

      BookName,
      Author,
      Language
}
