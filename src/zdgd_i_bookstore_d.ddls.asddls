@AbapCatalog.deliveryClass: #APPLICATION_DATA

@AccessControl.authorizationCheck: #NOT_REQUIRED

@ClientHandling.type: #CLIENT_DEPENDENT

@EndUserText.label: 'Draft: Bookstore'

define table entity ZDGD_I_Bookstore_D

{
  key BookstoreID    : sysuuid_x16;

      BookstoreName : abap.char(50);
      City          : abap.char(50);

      //      include ZDGD_RAPAdminFields.* signature only; //Aspects not supported yet in Service Binding (Release 2608)
      @Semantics.user.createdBy: true
      LocalCreatedBy     : abp_creation_user;

      @Semantics.systemDateTime.createdAt: true
      LocalCreatedAt     : abp_creation_tstmpl;

      @Semantics.user.localInstanceLastChangedBy: true
      LocalLastChangedBy : abp_locinst_lastchange_user;

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt : abp_locinst_lastchange_tstmpl;

      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt      : abp_lastchange_tstmpl;

      include SYCH_BDL_DRAFT_ADMIN_INC.* signature only;

}
