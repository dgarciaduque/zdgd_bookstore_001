*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lhc_bookstore DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Bookstore RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR bookstore RESULT result.

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
ENDCLASS.

CLASS ltcl_book_master_data DEFINITION DEFERRED FOR TESTING.

CLASS lhc_book DEFINITION
  INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_book_master_data.

  PRIVATE SECTION.
    CONSTANTS state_area_master_data TYPE string VALUE 'BOOK_MASTER_DATA'.

    METHODS validate_book_master_data FOR VALIDATE ON SAVE
      keys FOR Book~validate_book_master_data.

ENDCLASS.


CLASS lhc_book IMPLEMENTATION.
  METHOD validate_book_master_data.
    DATA master_books TYPE HASHED TABLE OF zdgd_i_bookmasterdata WITH UNIQUE KEY BookID.

    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
         ENTITY Book
         FIELDS ( BookID BookName Author Language )
         WITH CORRESPONDING #( keys )
         RESULT DATA(books).

    SELECT
      FROM @books AS b
             JOIN
               zdgd_i_bookmasterdata WITH PRIVILEGED ACCESS AS md ON b~BookID = md~BookID
      FIELDS DISTINCT md~BookID,
                      md~BookName,
                      md~Author,
                      md~Language
      INTO CORRESPONDING FIELDS OF TABLE @master_books.

    LOOP AT books INTO DATA(book).
      APPEND VALUE #( %tky        = book-%tky
                      %state_area = state_area_master_data ) TO reported-book.
      TRY.
          DATA(master) = master_books[ BookID = book-BookID ].
        CATCH cx_sy_itab_line_not_found.
          APPEND VALUE #( %tky = book-%tky ) TO failed-book.
          APPEND VALUE #( %tky            = book-%tky
                          %state_area     = state_area_master_data
                          %msg            = NEW zdgd_bookstore_exception(
                                                    textid = zdgd_bookstore_exception=>book_not_in_master_data )
                          %element-BookID = if_abap_behv=>mk-on ) TO reported-book.
          CONTINUE.
      ENDTRY.

      IF    book-BookName <> master-BookName
         OR book-Author   <> master-Author
         OR book-Language <> master-Language.
        APPEND VALUE #( %tky = book-%tky ) TO failed-book.
        APPEND VALUE #( %tky              = book-%tky
                        %state_area       = state_area_master_data
                        %msg              = NEW zdgd_bookstore_exception(
                                                    textid = zdgd_bookstore_exception=>book_not_in_master_data )
                        %element-BookName = COND #( WHEN book-BookName <> master-BookName
                                                    THEN if_abap_behv=>mk-on
                                                    ELSE if_abap_behv=>mk-off )
                        %element-Author   = COND #( WHEN book-Author <> master-Author
                                                    THEN if_abap_behv=>mk-on
                                                    ELSE if_abap_behv=>mk-off )
                        %element-Language = COND #( WHEN book-Language <> master-Language
                                                    THEN if_abap_behv=>mk-on
                                                    ELSE if_abap_behv=>mk-off ) )
               TO reported-book.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
