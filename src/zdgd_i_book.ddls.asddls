@AbapCatalog.deliveryClass: #APPLICATION_DATA

@AccessControl.authorizationCheck: #NOT_REQUIRED

@ClientHandling.type: #CLIENT_DEPENDENT

@EndUserText.label: 'Bookstore Books'

define table entity ZDGD_I_Book

{
      @Semantics.uuid: true
  key BookstoreID  : sysuuid_x16;

      @Semantics.uuid: true
  key BookID       : sysuuid_x16;

      BookName     : ZDGD_BookName;
      Author       : ZDGD_BookAuthor;
      UnitsInStock : abap.int1;

      @Semantics.language: true
      Language     : spras;

      _Bookstore   : association to parent ZDGD_I_Bookstore on $projection.bookstoreid = _Bookstore.bookstoreid;
      _BookMasterData: association of many to exact one ZDGD_I_BookMasterData on $projection.BookID = _BookMasterData.BookID;
}
