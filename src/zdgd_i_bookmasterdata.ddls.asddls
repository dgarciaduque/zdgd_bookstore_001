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

      //include ZDGD_RAPAdminFields.* signature only; //Aspects not supported yet in Service Binding (Release 2608)
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
}
