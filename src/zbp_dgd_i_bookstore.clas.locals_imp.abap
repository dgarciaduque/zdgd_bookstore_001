*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS ltcl_book_numbering DEFINITION DEFERRED FOR TESTING.

CLASS lhc_bookstore DEFINITION
  INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_book_numbering.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Bookstore RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR bookstore RESULT result.
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
    TYPES: BEGIN OF assigned_key,
             BookstoreID TYPE sysuuid_x16,
             parent_cid  TYPE abp_behv_cid,
             BookID      TYPE sysuuid_x16,
           END OF assigned_key.
    TYPES: BEGIN OF existing_assignment,
             BookstoreID TYPE sysuuid_x16,
             BookID      TYPE sysuuid_x16,
           END OF existing_assignment.

    DATA requested_books TYPE SORTED TABLE OF semantic_key WITH NON-UNIQUE KEY BookName Author Language.
    DATA master_books    TYPE HASHED TABLE OF master_data WITH UNIQUE KEY BookName Author Language.
    DATA requested_assignments TYPE SORTED TABLE OF existing_assignment WITH NON-UNIQUE KEY BookstoreID BookID.
    DATA existing_assignments TYPE SORTED TABLE OF existing_assignment WITH UNIQUE KEY BookstoreID BookID.
    DATA error_message TYPE REF TO if_abap_behv_message.
    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA assigned_keys   TYPE HASHED TABLE OF assigned_key WITH UNIQUE KEY BookstoreID parent_cid BookID.

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

    LOOP AT entities INTO DATA(requested_store) WHERE BookstoreID IS NOT INITIAL.
      LOOP AT requested_store-%target INTO DATA(requested_book).
        TRY.
            DATA(candidate_master) = master_books[ BookName = requested_book-BookName
                                                  Author   = requested_book-Author
                                                  Language = requested_book-Language ].
            APPEND VALUE #( BookstoreID = requested_store-BookstoreID
                            BookID      = candidate_master-BookID ) TO requested_assignments.
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.
      ENDLOOP.
    ENDLOOP.

    IF requested_assignments IS NOT INITIAL.
      SELECT FROM @requested_assignments AS requested
               JOIN zdgd_i_book WITH PRIVILEGED ACCESS AS existing ON  requested~BookstoreID = existing~BookstoreID
                                                                    AND requested~BookID      = existing~BookID
        FIELDS DISTINCT existing~BookstoreID,
                        existing~BookID
        INTO TABLE @existing_assignments.
    ENDIF.

    LOOP AT entities INTO DATA(entity_store).
      LOOP AT entity_store-%target INTO DATA(target_book).
        DATA(error_text) = VALUE string( ).
        TRY.
            DATA(master_data_row) = master_books[ BookName = target_book-BookName
                                                  Author   = target_book-Author
                                                  Language = target_book-Language ].
            IF target_book-BookID IS NOT INITIAL AND target_book-BookID <> master_data_row-BookID.
              error_text = 'Book ID conflicts with matching master book'.
            ELSE.
              DATA(resolved_book_id) = master_data_row-BookID.
            ENDIF.
          CATCH cx_sy_itab_line_not_found.
            error_text = 'No master book matches name, author and language'.
        ENDTRY.

        IF error_text IS INITIAL
           AND entity_store-BookstoreID IS NOT INITIAL
           AND line_exists( existing_assignments[ BookstoreID = entity_store-BookstoreID
                                                  BookID      = resolved_book_id ] ).
          error_text = 'Book already exists in this bookstore'.
        ENDIF.

        IF error_text IS INITIAL.
          INSERT VALUE #( BookstoreID = entity_store-BookstoreID
                          parent_cid  = COND #( WHEN entity_store-BookstoreID IS INITIAL
                                                THEN entity_store-%cid_ref
                                                ELSE space )
                          BookID      = resolved_book_id ) INTO TABLE assigned_keys.
          IF sy-subrc <> 0.
            error_text = 'Master book requested twice for this bookstore'.
          ENDIF.
        ENDIF.

        IF error_text IS NOT INITIAL.
          IF error_text = 'Book already exists in this bookstore'.
            error_message = NEW zdgd_bookstore_exception(
                                textid = zdgd_bookstore_exception=>book_already_exists ).
          ELSE.
            error_message = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                   text     = error_text ).
          ENDIF.

          APPEND VALUE #( %cid        = target_book-%cid
                          %is_draft   = entity_store-%is_draft
                          BookstoreID = entity_store-BookstoreID
                          BookID      = target_book-BookID
                          %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-book.
          APPEND VALUE #( %cid              = target_book-%cid
                          %is_draft         = entity_store-%is_draft
                          BookstoreID       = entity_store-BookstoreID
                          BookID            = target_book-BookID
                          %element-BookName = if_abap_behv=>mk-on
                          %element-Author   = if_abap_behv=>mk-on
                          %element-Language = if_abap_behv=>mk-on
                          %msg              = error_message ) TO reported-book.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid        = target_book-%cid
                        %is_draft   = entity_store-%is_draft
                        BookstoreID = entity_store-BookstoreID
                        BookID      = resolved_book_id ) TO mapped-book.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_book_master_data DEFINITION DEFERRED FOR TESTING.

CLASS lhc_book DEFINITION
  INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_book_master_data.

  PRIVATE SECTION.
    CONSTANTS state_area_master_data TYPE string VALUE 'BOOK_MASTER_DATA'.
    CONSTANTS state_area_duplicate_book TYPE string VALUE 'BOOK_ALREADY_EXISTS'.

    METHODS validate_book_master_data FOR VALIDATE ON SAVE
      keys FOR Book~validate_book_master_data.
    METHODS validate_book_already_exists FOR VALIDATE ON SAVE
      keys FOR Book~validate_book_already_exists.

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

  METHOD validate_book_already_exists.
    TYPES: BEGIN OF existing_assignment,
             BookstoreID TYPE sysuuid_x16,
             BookID      TYPE sysuuid_x16,
           END OF existing_assignment.

    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
         ENTITY Book
         FIELDS ( BookstoreID BookID )
         WITH CORRESPONDING #( keys )
         RESULT DATA(books).

    IF books IS INITIAL.
      RETURN.
    ENDIF.

    DATA existing_assignments TYPE SORTED TABLE OF existing_assignment
                   WITH NON-UNIQUE KEY BookstoreID BookID.

    SELECT
      FROM @books AS requested
             JOIN
               zdgd_i_book WITH PRIVILEGED ACCESS AS existing ON  requested~BookstoreID = existing~BookstoreID
                                                              AND requested~BookID      = existing~BookID
      FIELDS DISTINCT existing~BookstoreID,
                      existing~BookID
      INTO TABLE @existing_assignments.

    LOOP AT books INTO DATA(book).
      APPEND VALUE #( %tky        = book-%tky
                      %state_area = state_area_duplicate_book ) TO reported-book.

      IF NOT line_exists( existing_assignments[ BookstoreID = book-BookstoreID
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

