@AbapCatalog.deliveryClass: #APPLICATION_DATA

@AccessControl.authorizationCheck: #NOT_REQUIRED

@ClientHandling.type: #CLIENT_DEPENDENT

@EndUserText.label: 'Draft: Book'

define table entity ZDGD_I_Book_D

{
  key BookID     : sysuuid_x16;

      BookstoreID    : sysuuid_x16;
      BookName       : abap.char(50);
      Author         : abap.char(50);
//      include ZDGD_RAPAdminFields     .* signature only;
      include SYCH_BDL_DRAFT_ADMIN_INC.* signature only;
}
