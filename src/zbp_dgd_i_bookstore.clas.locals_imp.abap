*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lhc_bookstore DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Bookstore RESULT result.

ENDCLASS.

CLASS lhc_bookstore IMPLEMENTATION.
  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys
                      ( %tky    = key-%tky
                        %update = if_abap_behv=>auth-allowed
                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

ENDCLASS.

