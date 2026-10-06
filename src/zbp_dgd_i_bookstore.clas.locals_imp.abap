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
    TYPES: BEGIN OF resolution,
             BookName TYPE zdgd_bookname,
             Author   TYPE zdgd_bookauthor,
             Language TYPE spras,
             BookID   TYPE sysuuid_x16,
             matches  TYPE i,
           END OF resolution.
    TYPES: BEGIN OF assigned_key,
             BookstoreID TYPE sysuuid_x16,
             parent_cid  TYPE abp_behv_cid,
             BookID      TYPE sysuuid_x16,
           END OF assigned_key.

    DATA requested_books TYPE SORTED TABLE OF semantic_key
                         WITH UNIQUE KEY BookName Author Language.
    DATA resolutions     TYPE HASHED TABLE OF resolution WITH UNIQUE KEY BookName Author Language.
    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA assigned_keys   TYPE HASHED TABLE OF assigned_key WITH UNIQUE KEY BookstoreID parent_cid BookID.

    LOOP AT entities INTO DATA(store).
      LOOP AT store-%target INTO DATA(target).
        INSERT VALUE #( BookName = target-BookName
                        Author   = target-Author
                        Language = target-Language ) INTO TABLE requested_books.
      ENDLOOP.
    ENDLOOP.

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
      INTO TABLE @DATA(master_books).

    LOOP AT master_books INTO DATA(master_book).
      ASSIGN resolutions[ BookName = master_book-BookName
                          Author   = master_book-Author
                          Language = master_book-Language ] TO FIELD-SYMBOL(<resolution>).
      IF sy-subrc = 0.
        <resolution>-matches += 1.
      ELSE.
        INSERT VALUE #( BookName = master_book-BookName
                        Author   = master_book-Author
                        Language = master_book-Language
                        BookID   = master_book-BookID
                        matches  = 1 ) INTO TABLE resolutions.
      ENDIF.
    ENDLOOP.

    LOOP AT entities INTO store.
      LOOP AT store-%target INTO target.
        DATA(error_text) = VALUE string( ).
        DATA(resolved_book_id) = VALUE sysuuid_x16( ).
        ASSIGN resolutions[ BookName = target-BookName
                            Author   = target-Author
                            Language = target-Language ] TO <resolution>.
        IF sy-subrc <> 0.
          IF target-BookID IS INITIAL.
            error_text = 'No master book matches name, author and language'.
          ELSE.
            resolved_book_id = target-BookID.
          ENDIF.
        ELSEIF <resolution>-matches <> 1.
          error_text = 'Ambiguous master book: name, author and language'.
        ELSEIF target-BookID IS NOT INITIAL AND target-BookID <> <resolution>-BookID.
          error_text = 'Book ID conflicts with matching master book'.
        ELSE.
          resolved_book_id = <resolution>-BookID.
        ENDIF.

        IF error_text IS INITIAL.
          INSERT VALUE #( BookstoreID = store-BookstoreID
                          parent_cid  = COND #( WHEN store-BookstoreID IS INITIAL
                                                THEN store-%cid_ref
                                                ELSE space )
                          BookID      = resolved_book_id ) INTO TABLE assigned_keys.
          IF sy-subrc <> 0.
            error_text = 'Master book requested twice for this bookstore'.
          ENDIF.
        ENDIF.

        IF error_text IS NOT INITIAL.
          APPEND VALUE #( %cid        = target-%cid
                          %is_draft   = store-%is_draft
                          BookstoreID = store-BookstoreID
                          BookID      = target-BookID
                          %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-book.
          APPEND VALUE #( %cid              = target-%cid
                          %is_draft         = store-%is_draft
                          BookstoreID       = store-BookstoreID
                          BookID            = target-BookID
                          %element-BookName = if_abap_behv=>mk-on
                          %element-Author   = if_abap_behv=>mk-on
                          %element-Language = if_abap_behv=>mk-on
                          %msg              = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                                     text     = error_text ) ) TO reported-book.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid        = target-%cid
            %is_draft   = store-%is_draft
                        BookstoreID = store-BookstoreID
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

    METHODS validate_book_master_data FOR VALIDATE ON SAVE
      keys FOR Book~validate_book_master_data.
    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR Book RESULT result.

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

  METHOD get_instance_features.
    DATA persisted_books TYPE HASHED TABLE OF zdgd_i_book WITH UNIQUE KEY BookstoreID BookID.

    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
         ENTITY Book
         FIELDS ( BookstoreID BookID )
         WITH CORRESPONDING #( keys )
         RESULT DATA(books)
         FAILED failed
         REPORTED reported.

    IF books IS INITIAL.
      RETURN.
    ENDIF.

    SELECT
      FROM @books AS current_book
             JOIN
               zdgd_i_book AS persisted_book ON  current_book~BookstoreID = persisted_book~BookstoreID
                                             AND current_book~BookID      = persisted_book~BookID
      FIELDS DISTINCT persisted_book~BookstoreID,
                      persisted_book~BookID
      INTO CORRESPONDING FIELDS OF TABLE @persisted_books.

    LOOP AT books INTO DATA(book).
      DATA(field_control) = COND #( WHEN line_exists( persisted_books[ BookstoreID = book-BookstoreID
                                                                       BookID      = book-BookID ] )
                                    THEN if_abap_behv=>fc-f-read_only
                                    ELSE if_abap_behv=>fc-f-unrestricted ).
      APPEND VALUE #( %tky            = book-%tky
                      %field-BookName = field_control
                      %field-Author   = field_control
                      %field-Language = field_control ) TO result.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

