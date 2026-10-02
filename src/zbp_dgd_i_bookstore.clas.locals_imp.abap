*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lhc_bookstore DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Bookstore RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR bookstore RESULT result.
*    METHODS validate_book_master_data FOR VALIDATE ON SAVE
*      keys FOR Bookstore~validate_book_master_data.

ENDCLASS.

CLASS lhc_bookstore IMPLEMENTATION.
  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys
                      ( %tky    = key-%tky
                        %update = if_abap_behv=>auth-allowed
                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    result-%create = if_abap_behv=>auth-allowed.
  ENDMETHOD.

*  METHOD validate_book_master_data.
*    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
*         ENTITY Bookstore BY \_Books
*         FIELDS ( BookID )
*         WITH CORRESPONDING #( keys )
*         RESULT DATA(books).
*
*    IF books IS NOT INITIAL.
*      SELECT
*        FROM @books AS input
*               JOIN
*                 zdgd_i_bookmasterdata WITH PRIVILEGED ACCESS AS md ON input~BookID = md~BookID
*        FIELDS md~BookID
*        INTO TABLE @DATA(master_book_ids).
*    ENDIF.
*
*    LOOP AT books INTO DATA(book).
*      IF        book-BookID IS INITIAL
*         OR NOT line_exists( master_book_ids[ BookID = book-BookID ] ).
*        APPEND VALUE #( %tky  = book-%tky ) TO failed-Book.
*        APPEND VALUE #( %tky            = book-%tky
*                        %msg            = new_message_with_text( severity = if_abap_behv_message=>severity-error
*                                                                 text     = 'Book must exist in master data.' )
*                        %element-BookID = if_abap_behv=>mk-on ) TO reported-Book.
*      ENDIF.
*    ENDLOOP.
*  ENDMETHOD.

ENDCLASS.

CLASS lhc_book DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS validate_book_master_data FOR VALIDATE ON SAVE
      keys FOR Book~validate_book_master_data.

ENDCLASS.

CLASS lhc_book IMPLEMENTATION.

  METHOD validate_book_master_data.
  ENDMETHOD.

ENDCLASS.

