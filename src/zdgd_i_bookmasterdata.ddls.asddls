@AbapCatalog.deliveryClass: #APPLICATION_DATA

@AccessControl.authorizationCheck: #NOT_REQUIRED

@ClientHandling.type: #CLIENT_DEPENDENT

@EndUserText.label: 'Book Master Data'

@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MASTER }

define root table entity ZDGD_I_BookMasterData

{
      @Semantics.uuid: true
  key BookID       : sysuuid_x16;

      BookName     : ZDGD_BookName;
      Author       : ZDGD_BookAuthor;

      @Semantics.language: true
      Language     : spras;

      include ZDGD_RAPAdminFields.* signature only;
}
