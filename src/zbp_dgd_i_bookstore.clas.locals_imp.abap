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

  TYPES: BEGIN OF request_candidate,
           cid         TYPE abp_behv_cid,
           parent_cid  TYPE abp_behv_cid,
           BookstoreID TYPE zdgd_i_book-BookstoreID,
           BookID      TYPE zdgd_i_book-BookID,
         END OF request_candidate.
  TYPES request_candidates TYPE STANDARD TABLE OF request_candidate WITH EMPTY KEY.

  TYPES: BEGIN OF master_candidate,
           BookID   TYPE zdgd_i_book-BookID,
           BookName TYPE zdgd_i_book-BookName,
           Author   TYPE zdgd_i_book-Author,
           Language TYPE zdgd_i_book-Language,
         END OF master_candidate.
  TYPES master_candidates TYPE STANDARD TABLE OF master_candidate WITH EMPTY KEY.
  TYPES: BEGIN OF master_finding,
           BookID            TYPE zdgd_i_book-BookID,
           BookName          TYPE zdgd_i_book-BookName,
           Author            TYPE zdgd_i_book-Author,
           Language          TYPE zdgd_i_book-Language,
           name_mismatch     TYPE abap_bool,
           author_mismatch   TYPE abap_bool,
           language_mismatch TYPE abap_bool,
         END OF master_finding.
  TYPES master_findings TYPE HASHED TABLE OF master_finding
    WITH UNIQUE KEY BookID BookName Author Language.

  METHODS find_duplicates_in_bookstore IMPORTING books             TYPE book_keys
                                       RETURNING VALUE(duplicates) TYPE book_keys.

  METHODS find_request_duplicates IMPORTING books                 TYPE request_candidates
                                   RETURNING VALUE(duplicates) TYPE request_candidates.

  METHODS find_invalid_master_data IMPORTING books                TYPE master_candidates
                                   RETURNING VALUE(invalid_books) TYPE master_findings.
ENDINTERFACE.


INTERFACE lif_messages.
  CONSTANTS message_class TYPE symsgid VALUE 'ZDGD_BOOKSTORE'.
  CONSTANTS: BEGIN OF message_no,
               entries_restocked_correctly TYPE symsgno VALUE '007',
             END OF message_no.

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
    METHODS getdefaultsforrestockbook FOR READ
      keys FOR FUNCTION bookstore~getdefaultsforrestockbook RESULT result.

    METHODS restockbook FOR MODIFY
      keys FOR ACTION bookstore~restockbook.
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
    IF requested_authorizations-%action-ReStockBook = if_abap_behv=>mk-on.
      result-%action-ReStockBook = if_abap_behv=>auth-allowed.
    ENDIF.
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

    LOOP AT entities INTO DATA(entity_store).
      LOOP AT entity_store-%target INTO DATA(target_book).
        TRY.
            DATA(master_data_row) = master_books[ BookName = target_book-BookName
                                                  Author   = target_book-Author
                                                  Language = target_book-Language ].
            APPEND VALUE #( %cid        = target_book-%cid
                            %is_draft   = entity_store-%is_draft
                            BookstoreID = entity_store-BookstoreID
                            BookID      = master_data_row-BookID ) TO mapped-book.
          CATCH cx_sy_itab_line_not_found.
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
                            %msg              = NEW zdgd_bookstore_exception(
                                                        textid = zdgd_bookstore_exception=>book_not_in_master_data ) ) TO reported-book.
        ENDTRY.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_cba_Books.
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
    TYPES: BEGIN OF resolved_book,
             cid         TYPE abp_behv_cid,
             is_draft    TYPE abp_behv_flag,
             parent_cid  TYPE abp_behv_cid,
             BookstoreID TYPE zdgd_i_book-BookstoreID,
             BookID      TYPE zdgd_i_book-BookID,
           END OF resolved_book.
    TYPES resolved_books TYPE STANDARD TABLE OF resolved_book WITH EMPTY KEY.

    DATA requested_books TYPE SORTED TABLE OF semantic_key
      WITH UNIQUE KEY BookName Author Language.
    DATA master_books    TYPE SORTED TABLE OF master_data
      WITH UNIQUE KEY BookName Author Language.
    DATA resolved        TYPE resolved_books.
    DATA requested_keys  TYPE lif_book_validation=>book_keys.

    " Prechecks are done only for draft instances,
    " because validations on save are not executed when creating a new draft instance.
    " If we don't do this, we will get a short dump when, e.g., there's a duplicate key.
    LOOP AT entities INTO DATA(entity_store).
      IF entity_store-%is_draft <> if_abap_behv=>mk-on.
        CONTINUE.
      ENDIF.
      LOOP AT entity_store-%target INTO DATA(target_book).
        INSERT VALUE #( BookName = target_book-BookName
                        Author   = target_book-Author
                        Language = target_book-Language ) INTO TABLE requested_books.
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
      INTO TABLE @master_books.

    LOOP AT entities INTO entity_store.
      IF entity_store-%is_draft <> if_abap_behv=>mk-on.
        CONTINUE.
      ENDIF.
      LOOP AT entity_store-%target INTO target_book.
        TRY.
            DATA(master_row) = master_books[ BookName = target_book-BookName
                                             Author   = target_book-Author
                                             Language = target_book-Language ].
            DATA(parent_cid) = COND abp_behv_cid(
              WHEN entity_store-BookstoreID IS INITIAL
              THEN entity_store-%cid_ref
              ELSE CONV abp_behv_cid( '' ) ).
            APPEND VALUE #( cid         = target_book-%cid
                            is_draft    = entity_store-%is_draft
                            parent_cid  = parent_cid
                            BookstoreID = entity_store-BookstoreID
                            BookID      = master_row-BookID ) TO resolved.
            INSERT VALUE #( BookstoreID = entity_store-BookstoreID
                            BookID      = master_row-BookID ) INTO TABLE requested_keys.
          CATCH cx_sy_itab_line_not_found.
            APPEND VALUE #( %cid        = target_book-%cid
                            %is_draft   = entity_store-%is_draft
                            BookstoreID = entity_store-BookstoreID ) TO failed-book.
            APPEND VALUE #( %cid              = target_book-%cid
                            %is_draft         = entity_store-%is_draft
                            BookstoreID       = entity_store-BookstoreID
                            BookID            = target_book-BookID
                            %element-BookName = if_abap_behv=>mk-on
                            %element-Author   = if_abap_behv=>mk-on
                            %element-Language = if_abap_behv=>mk-on
                            %msg              = NEW zdgd_bookstore_exception(
                                                        textid = zdgd_bookstore_exception=>book_not_in_master_data ) ) TO reported-book.
        ENDTRY.
      ENDLOOP.
    ENDLOOP.

    DATA(request_duplicates) = lcl_book_validation=>get_instance( )->find_request_duplicates(
                                   books = CORRESPONDING #( resolved ) ).

    DATA(existing_keys) = lcl_book_validation=>get_instance( )->find_duplicates_in_bookstore( books = requested_keys ).

    LOOP AT resolved INTO DATA(candidate).
      IF line_exists( request_duplicates[ cid         = candidate-cid
                                          parent_cid  = candidate-parent_cid
                                          BookstoreID = candidate-BookstoreID
                                          BookID      = candidate-BookID ] ).
        APPEND VALUE #( %cid        = candidate-cid
                        %is_draft   = candidate-is_draft
                        BookstoreID = candidate-BookstoreID
                        BookID      = candidate-BookID ) TO failed-book.
        APPEND VALUE #( %cid            = candidate-cid
                        %is_draft       = candidate-is_draft
                        BookstoreID     = candidate-BookstoreID
                        BookID          = candidate-BookID
                        %element-BookID = if_abap_behv=>mk-on
                        %msg            = NEW zdgd_bookstore_exception(
                                                  textid = zdgd_bookstore_exception=>request_contains_duplicates ) )
               TO reported-book.
      ELSEIF line_exists( existing_keys[ BookstoreID = candidate-BookstoreID
                                         BookID      = candidate-BookID ] ).
        APPEND VALUE #( %cid        = candidate-cid
                        %is_draft   = candidate-is_draft
                        BookstoreID = candidate-BookstoreID
                        BookID      = candidate-BookID ) TO failed-book.
        APPEND VALUE #( %cid            = candidate-cid
                        %is_draft       = candidate-is_draft
                        BookstoreID     = candidate-BookstoreID
                        BookID          = candidate-BookID
                        %element-BookID = if_abap_behv=>mk-on
                        %msg            = NEW zdgd_bookstore_exception(
                                                  textid = zdgd_bookstore_exception=>book_already_exists ) )
               TO reported-book.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD GetDefaultsForRestockBook.
    CONSTANTS stock_threshold TYPE zdgd_d_restockbookparam-StockThreshold VALUE 3.
    CONSTANTS target_stock    TYPE zdgd_d_restockbookparam-TargetStock    VALUE 10.

    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Propose the book that would have the highest amount of units re-stocked.
    SELECT FROM zdgd_i_book
      FIELDS BookID,
             SUM( @target_stock - UnitsInStock ) AS replenishment
      WHERE UnitsInStock < @stock_threshold
      GROUP BY BookID
      ORDER BY replenishment DESCENDING,
               BookID ASCENDING
      INTO TABLE @DATA(candidates)
      UP TO 1 ROWS.

    DATA(book_id) = VALUE #( candidates[ 1 ]-BookID OPTIONAL ).
    result = VALUE #( FOR request IN keys
                      ( VALUE #( BASE CORRESPONDING #( request )
                                 %param = VALUE #( BookID         = book_id
                                                   StockThreshold = stock_threshold
                                                   TargetStock    = target_stock ) ) ) ).
  ENDMETHOD.

  METHOD ReStockBook.
    DATA request          TYPE STRUCTURE FOR ACTION IMPORT zdgd_i_bookstore\\bookstore~restockbook.
    DATA master_candidate TYPE lif_book_validation=>master_candidate.
    DATA invalid_books    TYPE lif_book_validation=>master_findings.
    DATA candidate_keys   TYPE lif_book_validation=>book_keys.
    DATA books            TYPE TABLE FOR READ RESULT zdgd_i_bookstore\\Book.
    DATA updates          TYPE TABLE FOR UPDATE zdgd_i_bookstore\\Book.
    DATA read_failed      TYPE RESPONSE FOR FAILED EARLY zdgd_i_bookstore.
    DATA read_reported    TYPE RESPONSE FOR REPORTED EARLY zdgd_i_bookstore.
    DATA update_failed    TYPE RESPONSE FOR FAILED EARLY zdgd_i_bookstore.
    DATA update_reported  TYPE RESPONSE FOR REPORTED EARLY zdgd_i_bookstore.

    LOOP AT keys INTO request.
      IF request-%param-TargetStock <= request-%param-StockThreshold.
        APPEND VALUE #( %cid = request-%cid ) TO failed-bookstore.
        APPEND VALUE #( %cid = request-%cid
                        %msg = NEW zdgd_bookstore_exception(
                                       textid = zdgd_bookstore_exception=>invalid_restock_target ) )
               TO reported-bookstore.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zdgd_i_bookmasterdata
        FIELDS BookID, BookName, Author, Language
        WHERE BookID = @request-%param-BookID
        INTO @master_candidate.
      master_candidate-BookID = request-%param-BookID.

      invalid_books = lcl_book_validation=>get_instance( )->find_invalid_master_data(
                          books = VALUE #( ( master_candidate ) ) ).
      IF request-%param-BookID IS INITIAL OR invalid_books IS NOT INITIAL.
        APPEND VALUE #( %cid = request-%cid ) TO failed-bookstore.
        APPEND VALUE #( %cid = request-%cid
                        %msg = NEW zdgd_bookstore_exception(
                                       textid = zdgd_bookstore_exception=>book_not_in_master_data ) )
               TO reported-bookstore.
        CONTINUE.
      ENDIF.

      SELECT FROM zdgd_i_book
        FIELDS BookstoreID, BookID
        WHERE BookID       = @request-%param-BookID
          AND UnitsInStock < @request-%param-StockThreshold
        INTO TABLE @candidate_keys.

      READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
           ENTITY Book
           FIELDS ( UnitsInStock )
           WITH VALUE #( FOR candidate IN candidate_keys
                         ( BookstoreID = candidate-BookstoreID
                           BookID      = candidate-BookID
                           %is_draft   = if_abap_behv=>mk-off ) )
           RESULT books
           FAILED read_failed
           REPORTED read_reported.

      updates = VALUE #( FOR book IN books
                         WHERE ( UnitsInStock < request-%param-StockThreshold )
                         ( %tky         = book-%tky
                           UnitsInStock = request-%param-TargetStock ) ).

      MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
             ENTITY Book
             UPDATE FIELDS ( UnitsInStock ) WITH updates
             FAILED update_failed
             REPORTED update_reported.

      APPEND LINES OF read_reported-book TO reported-book.
      APPEND LINES OF read_reported-bookstore TO reported-bookstore.
      APPEND LINES OF update_reported-book TO reported-book.
      APPEND LINES OF update_reported-bookstore TO reported-bookstore.

      IF read_failed IS NOT INITIAL OR update_failed IS NOT INITIAL.
        APPEND VALUE #( %cid = request-%cid ) TO failed-bookstore.
        APPEND VALUE #( %cid = request-%cid
                        %msg = NEW zdgd_bookstore_exception( textid = zdgd_bookstore_exception=>restock_failed ) )
               TO reported-bookstore.
      ELSEIF updates IS INITIAL.
        APPEND VALUE #( %cid = request-%cid
                        %msg = NEW zdgd_bookstore_exception( textid   = zdgd_bookstore_exception=>no_restock_candidates
                                                             severity = if_abap_behv_message=>severity-information ) )
               TO reported-bookstore.
      ELSE.
        APPEND VALUE #( %cid = request-%cid
                        %msg = new_message( id       = lif_messages=>message_class
                                            number   = lif_messages=>message_no-entries_restocked_correctly
                                            severity = if_abap_behv_message=>severity-success
                                            v1       = lines( updates )
                                            v2       = request-%param-TargetStock ) )
               TO reported-bookstore.
      ENDIF.
    ENDLOOP.
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
    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
         ENTITY Book
         FIELDS ( BookID BookName Author Language )
         WITH CORRESPONDING #( keys )
         RESULT DATA(books).

    DATA(invalid_books) = lcl_book_validation=>get_instance( )->find_invalid_master_data(
                              books = CORRESPONDING #( books ) ).

    LOOP AT books INTO DATA(book).
      APPEND VALUE #( %tky        = book-%tky
                      %state_area = state_area_master_data ) TO reported-book.
      TRY.
          DATA(finding) = invalid_books[ BookID   = book-BookID
                                         BookName = book-BookName
                                         Author   = book-Author
                                         Language = book-Language ].
        CATCH cx_sy_itab_line_not_found.
          CONTINUE.
      ENDTRY.

      APPEND VALUE #( %tky = book-%tky ) TO failed-book.
      APPEND VALUE #( %tky              = book-%tky
                      %state_area       = state_area_master_data
                      %path-Bookstore   = VALUE #( BookstoreID = book-BookstoreID
                                                   %is_draft   = book-%is_draft )
                      %msg              = NEW zdgd_bookstore_exception(
                                                  textid = zdgd_bookstore_exception=>book_not_in_master_data )
                      %element-BookName = COND #( WHEN finding-name_mismatch = abap_true
                                                  THEN if_abap_behv=>mk-on
                                                  ELSE if_abap_behv=>mk-off )
                      %element-Author   = COND #( WHEN finding-author_mismatch = abap_true
                                                  THEN if_abap_behv=>mk-on
                                                  ELSE if_abap_behv=>mk-off )
                      %element-Language = COND #( WHEN finding-language_mismatch = abap_true
                                                  THEN if_abap_behv=>mk-on
                                                  ELSE if_abap_behv=>mk-off ) )
             TO reported-book.
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
  METHOD lif_book_validation~find_request_duplicates.
    TYPES: BEGIN OF duplicate_count,
             BookstoreID TYPE zdgd_i_book-BookstoreID,
             parent_cid  TYPE abp_behv_cid,
             BookID      TYPE zdgd_i_book-BookID,
             occurrences TYPE i,
           END OF duplicate_count.

    DATA request_counts TYPE HASHED TABLE OF duplicate_count
      WITH UNIQUE KEY BookstoreID parent_cid BookID.

    LOOP AT books INTO DATA(book).
      DATA(request_count_ref) = REF #( request_counts[
        BookstoreID = book-BookstoreID
        parent_cid  = book-parent_cid
        BookID      = book-BookID ] OPTIONAL ).
      IF request_count_ref IS BOUND.
        request_count_ref->occurrences += 1.
      ELSE.
        INSERT VALUE #( BookstoreID = book-BookstoreID
                        parent_cid  = book-parent_cid
                        BookID      = book-BookID
                        occurrences = 1 ) INTO TABLE request_counts.
      ENDIF.
    ENDLOOP.

    LOOP AT books INTO book.
      DATA(request_count) = request_counts[ BookstoreID = book-BookstoreID
                                            parent_cid  = book-parent_cid
                                            BookID      = book-BookID ].
      IF request_count-occurrences > 1.
        APPEND book TO duplicates.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD lif_book_validation~find_invalid_master_data.
    IF books IS INITIAL.
      RETURN.
    ENDIF.

    DATA master_books TYPE HASHED TABLE OF lif_book_validation=>master_candidate WITH UNIQUE KEY BookID.
    SELECT
      FROM @books AS requested
             JOIN
               zdgd_i_bookmasterdata WITH PRIVILEGED ACCESS AS master ON requested~BookID = master~BookID
      FIELDS DISTINCT master~BookID,
                      master~BookName,
                      master~Author,
                      master~Language
      INTO TABLE @master_books.

    LOOP AT books INTO DATA(book).
      DATA(finding) = CORRESPONDING lif_book_validation=>master_finding( book ).
      TRY.
          DATA(master) = master_books[ BookID = book-BookID ].
          finding-name_mismatch = xsdbool( book-BookName <> master-BookName ).
          finding-author_mismatch = xsdbool( book-Author <> master-Author ).
          finding-language_mismatch = xsdbool( book-Language <> master-Language ).
        CATCH cx_sy_itab_line_not_found.
          finding-name_mismatch = abap_true.
          finding-author_mismatch = abap_true.
          finding-language_mismatch = abap_true.
      ENDTRY.

      IF finding-name_mismatch = abap_true
         OR finding-author_mismatch = abap_true
         OR finding-language_mismatch = abap_true.
        INSERT finding INTO TABLE invalid_books.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

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

