@AbapCatalog.deliveryClass: #APPLICATION_DATA

@AccessControl.authorizationCheck: #NOT_REQUIRED

@ClientHandling.type: #CLIENT_DEPENDENT

@EndUserText.label: 'Draft: Book Master Data'

define root table entity ZDGD_I_BOOKMASTERDATA_D

{
      @Semantics.uuid: true
  key BookID       : sysuuid_x16;

      BookName     : ZDGD_BookName;
      Author       : ZDGD_BookAuthor;

      @Semantics.language: true
      Language     : spras;

      include ZDGD_RAPAdminFields.* signature only;
      include SYCH_BDL_DRAFT_ADMIN_INC.* signature only;
}
