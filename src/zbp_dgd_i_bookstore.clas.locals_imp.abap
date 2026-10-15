*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS ltcl_book_numbering DEFINITION DEFERRED FOR TESTING.

INTERFACE lif_book_validation.
  TYPES: BEGIN OF book_key,
           BookstoreID TYPE zdgd_i_book-BookstoreID,
           BookID      TYPE zdgd_i_book-BookID,
         END OF book_key.
  TYPES book_keys TYPE SORTED TABLE OF book_key WITH UNIQUE KEY BookstoreID BookID.

  METHODS find_duplicates_in_bookstore IMPORTING books TYPE book_keys
                                       RETURNING VALUE(duplicates) TYPE book_keys.
ENDINTERFACE.

CLASS lcl_book_validation DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    INTERFACES lif_book_validation.
    CLASS-METHODS get_instance
      RETURNING VALUE(result) TYPE REF TO lif_book_validation.

  PRIVATE SECTION.
    CLASS-DATA self TYPE REF TO lcl_book_validation.
ENDCLASS.

CLASS lhc_bookstore DEFINITION
  INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_book_numbering.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Bookstore RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR bookstore RESULT result.
    METHODS precheck_cba_books FOR PRECHECK
      entities FOR CREATE bookstore\_books.
    METHODS earlynumbering_cba_books FOR NUMBERING
      entities FOR CREATE bookstore\_books.

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

  METHOD earlynumbering_cba_books.
    TYPES: BEGIN OF semantic_key,
             BookName TYPE zdgd_bookname,
             Author   TYPE zdgd_bookauthor,
             Language TYPE spras,
           END OF semantic_key.
    TYPES: BEGIN OF master_data,
             BookName TYPE zdgd_bookname,
             Author   TYPE zdgd_bookauthor,
             Language TYPE spras,
             BookID   TYPE sysuuid_x16,
           END OF master_data.
    DATA requested_books TYPE SORTED TABLE OF semantic_key WITH NON-UNIQUE KEY BookName Author Language.
    DATA master_books    TYPE SORTED TABLE OF master_data WITH UNIQUE KEY BookName Author Language.

    requested_books = VALUE #( FOR store IN entities
                               FOR target IN store-%target
                               ( BookName = target-BookName
                                 Author   = target-Author
                                 Language = target-Language ) ).
    DELETE ADJACENT DUPLICATES FROM requested_books COMPARING ALL FIELDS.

    IF requested_books IS INITIAL.
      RETURN.
    ENDIF.

    SELECT
      FROM @requested_books AS requested
             JOIN
               zdgd_i_bookmasterdata WITH PRIVILEGED ACCESS AS master ON  requested~BookName = master~BookName
                                                                      AND requested~Author   = master~Author
                                                                      AND requested~Language = master~Language
      FIELDS master~BookName,
             master~Author,
             master~Language,
             master~BookID
      INTO TABLE @master_books.

    mapped-book = VALUE #( FOR entity_store IN entities
                           FOR target_book IN entity_store-%target
                           LET master_data_row = VALUE #( master_books[ BookName = target_book-BookName
                                                                        Author   = target_book-Author
                                                                        Language = target_book-Language ] OPTIONAL ) IN
                           ( %cid        = target_book-%cid
                             %is_draft   = entity_store-%is_draft
                             BookstoreID = entity_store-BookstoreID
                             BookID      = master_data_row-BookID ) ).
    DELETE mapped-book WHERE BookID IS INITIAL.
  ENDMETHOD.

  METHOD precheck_cba_Books.
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_book_master_data DEFINITION DEFERRED FOR TESTING.

CLASS lhc_book DEFINITION
  INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_book_master_data.

  PRIVATE SECTION.
    CONSTANTS state_area_master_data    TYPE string VALUE 'BOOK_MASTER_DATA'.
    CONSTANTS state_area_duplicate_book TYPE string VALUE 'BOOK_ALREADY_EXISTS'.

    METHODS exists_in_master_data FOR VALIDATE ON SAVE
      keys FOR Book~exists_in_master_data.
    METHODS no_duplicates_in_bookstore FOR VALIDATE ON SAVE
      keys FOR Book~no_duplicates_in_bookstore.

ENDCLASS.


CLASS lhc_book IMPLEMENTATION.
  METHOD exists_in_master_data.
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
          APPEND VALUE #( %tky              = book-%tky
                          %state_area       = state_area_master_data
                          %path-Bookstore   = VALUE #( BookstoreID = book-BookstoreID
                                                       %is_draft   = book-%is_draft )
                          %msg              = NEW zdgd_bookstore_exception(
                                                      textid = zdgd_bookstore_exception=>book_not_in_master_data )
                          %element-BookName = if_abap_behv=>mk-on
                          %element-Author   = if_abap_behv=>mk-on
                          %element-Language = if_abap_behv=>mk-on ) TO reported-book.
          CONTINUE.
      ENDTRY.

      IF    book-BookName <> master-BookName
         OR book-Author   <> master-Author
         OR book-Language <> master-Language.
        APPEND VALUE #( %tky = book-%tky ) TO failed-book.
        APPEND VALUE #( %tky              = book-%tky
                        %state_area       = state_area_master_data
                        %path-Bookstore   = VALUE #( BookstoreID = book-BookstoreID
                                                     %is_draft   = book-%is_draft )
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

  METHOD no_duplicates_in_bookstore.
    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
         ENTITY Book
         FIELDS ( BookstoreID BookID )
         WITH CORRESPONDING #( keys )
         RESULT DATA(books).

    IF books IS INITIAL.
      RETURN.
    ENDIF.

    DATA(duplicate_books) = lcl_book_validation=>get_instance( )->find_duplicates_in_bookstore(
                                books = VALUE #( FOR candidate IN books
                                                 ( BookstoreID = candidate-BookstoreID
                                                   BookID      = candidate-BookID ) ) ).

    LOOP AT books INTO DATA(book).
      APPEND VALUE #( %tky        = book-%tky
                      %state_area = state_area_duplicate_book ) TO reported-book.

      IF NOT line_exists( duplicate_books[ BookstoreID = book-BookstoreID
                                           BookID      = book-BookID ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = book-%tky ) TO failed-book.
      APPEND VALUE #( %tky            = book-%tky
                      %state_area     = state_area_duplicate_book
                      %path-Bookstore = VALUE #( BookstoreID = book-BookstoreID
                                                 %is_draft   = book-%is_draft )
                      %msg            = NEW zdgd_bookstore_exception(
                                                textid = zdgd_bookstore_exception=>book_already_exists )
                      %element-BookID = if_abap_behv=>mk-on ) TO reported-book.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_book_validation IMPLEMENTATION.
  METHOD lif_book_validation~find_duplicates_in_bookstore.
    IF books IS INITIAL.
      RETURN.
    ENDIF.

    SELECT
      FROM @books AS requested
             JOIN
               zdgd_i_book WITH PRIVILEGED ACCESS AS existing ON  requested~BookstoreID = existing~BookstoreID
                                                              AND requested~BookID      = existing~BookID
      FIELDS DISTINCT existing~BookstoreID,
                      existing~BookID
      INTO TABLE @duplicates.
  ENDMETHOD.

  METHOD get_instance.
    IF self IS NOT BOUND.
      self = NEW #( ).
    ENDIF.
    result = self.
  ENDMETHOD.

ENDCLASS.

