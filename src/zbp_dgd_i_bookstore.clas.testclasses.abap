*"* use this source file for your ABAP unit test classes
CLASS ltcl_book_numbering DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES master_books    TYPE STANDARD TABLE OF zdgd_i_bookmasterdata WITH EMPTY KEY.
    TYPES draft_books     TYPE STANDARD TABLE OF zdgd_i_bookmasterdata_d WITH EMPTY KEY.
    TYPES persisted_books TYPE STANDARD TABLE OF zdgd_i_book WITH EMPTY KEY.

    CONSTANTS master_id TYPE sysuuid_x16 VALUE '00000000000000000000000000000002'.
    CONSTANTS other_id  TYPE sysuuid_x16 VALUE '00000000000000000000000000000003'.
    CONSTANTS store_id  TYPE sysuuid_x16 VALUE '00000000000000000000000000000001'.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA cut      TYPE REF TO lhc_bookstore.
    DATA requests TYPE TABLE FOR CREATE zdgd_i_bookstore\\Bookstore\_Books.
    DATA mapped   TYPE RESPONSE FOR MAPPED EARLY zdgd_i_bookstore.
    DATA failed   TYPE RESPONSE FOR FAILED EARLY zdgd_i_bookstore.
    DATA reported TYPE RESPONSE FOR REPORTED EARLY zdgd_i_bookstore.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    METHODS resolves_semantic_key          FOR TESTING.
    METHODS precheck_request_duplicates FOR TESTING.
    METHODS precheck_persisted_duplicate FOR TESTING.
    METHODS precheck_missing_master FOR TESTING.
    METHODS precheck_active_ignored FOR TESTING.
    METHODS helper_request_duplicates FOR TESTING.
    METHODS helper_parent_refs_distinct FOR TESTING.
    METHODS helper_empty_request FOR TESTING.
    METHODS preserves_matching_id          FOR TESTING.
    METHODS maps_supplied_id_from_master   FOR TESTING.
    METHODS rejects_missing_master         FOR TESTING.
    METHODS rejects_draft_only_master      FOR TESTING.
    METHODS active_failure_keeps_id        FOR TESTING.
    METHODS preserves_existing_responses   FOR TESTING.
    METHODS matches_all_semantic_fields    FOR TESTING.
    METHODS handles_mixed_batch            FOR TESTING.
    METHODS maps_duplicate_requests        FOR TESTING.
    METHODS maps_existing_assignment       FOR TESTING.
    METHODS allows_different_book_in_store FOR TESTING.
    METHODS allows_book_in_other_store     FOR TESTING.
    METHODS existing_other_store_passes    FOR TESTING.
    METHODS distinguishes_parent_refs      FOR TESTING.
    METHODS empty_requests                 FOR TESTING.
    METHODS empty_targets                  FOR TESTING.

    METHODS defaults_aggregate_stock FOR TESTING.
    METHODS defaults_threshold_boundary FOR TESTING.
    METHODS defaults_tie_by_book_id FOR TESTING.
    METHODS defaults_empty_inventory FOR TESTING.
    METHODS defaults_no_candidate FOR TESTING.
    METHODS defaults_large_total FOR TESTING.
    METHODS defaults_empty_requests FOR TESTING.
    METHODS restock_updates_only_eligible FOR TESTING.
    METHODS restock_rejects_missing_master FOR TESTING.
    METHODS restock_rejects_initial_book FOR TESTING.
    METHODS restock_rejects_invalid_target FOR TESTING.
    METHODS restock_no_assignments FOR TESTING.
    METHODS restock_zero_threshold FOR TESTING.
    METHODS restock_empty_requests FOR TESTING.
    METHODS restock_authorization FOR TESTING.
    METHODS execute_restock
      IMPORTING book_id TYPE sysuuid_x16 DEFAULT master_id
                threshold TYPE int1 DEFAULT 3
                target TYPE int1 DEFAULT 10.
    METHODS assert_restock_defaults
      IMPORTING expected_book_id TYPE sysuuid_x16 OPTIONAL.

    METHODS given_master
      IMPORTING book_id   TYPE sysuuid_x16     DEFAULT master_id
                book_name TYPE zdgd_bookname   DEFAULT 'Book A'
                author    TYPE zdgd_bookauthor DEFAULT 'Author A'
                !language TYPE spras           DEFAULT 'E'.

    METHODS given_request
      IMPORTING !cid         TYPE abp_behv_cid    DEFAULT 'BOOK'
                bookstore_id TYPE sysuuid_x16     DEFAULT store_id
                parent_cid   TYPE abp_behv_cid    OPTIONAL
                book_id      TYPE sysuuid_x16     OPTIONAL
                book_name    TYPE zdgd_bookname   DEFAULT 'Book A'
                author       TYPE zdgd_bookauthor DEFAULT 'Author A'
                !language    TYPE spras           DEFAULT 'E'
                is_draft     TYPE abp_behv_flag   DEFAULT if_abap_behv=>mk-on.

    METHODS when_numbered.

    METHODS assert_mapping
      IMPORTING !cid         TYPE abp_behv_cid  DEFAULT 'BOOK'
                bookstore_id TYPE sysuuid_x16   DEFAULT store_id
                book_id      TYPE sysuuid_x16   DEFAULT master_id
                is_draft     TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-on.

    METHODS assert_numbering_failure
      IMPORTING !cid         TYPE abp_behv_cid DEFAULT 'BOOK'
                book_id      TYPE sysuuid_x16 OPTIONAL
                is_draft     TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-on.
ENDCLASS.

CLASS ltcl_book_numbering IMPLEMENTATION.
  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZDGD_I_BOOKMASTERDATA' )
                     ( 'ZDGD_I_BOOKMASTERDATA_D' )
                     ( 'ZDGD_I_BOOKSTORE' )
                     ( 'ZDGD_I_BOOKSTORE_D' )
                     ( 'ZDGD_I_BOOK_D' )
                     ( 'ZDGD_I_BOOK' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    CREATE OBJECT cut FOR TESTING.
    CLEAR: requests, mapped, failed, reported.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    sql_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD execute_restock.
    cut->restockbook(
      EXPORTING keys = VALUE #( ( %cid = 'RESTOCK'
                                  %param = VALUE #( BookID = book_id
                                                    StockThreshold = threshold
                                                    TargetStock = target ) ) )
      CHANGING mapped = mapped failed = failed reported = reported ).
  ENDMETHOD.

  METHOD restock_updates_only_eligible.
    DATA success_message TYPE REF TO if_t100_dyn_msg.
    given_master( ).
    DATA stores TYPE STANDARD TABLE OF zdgd_i_bookstore WITH EMPTY KEY.
    stores = VALUE #( ( BookstoreID = store_id BookstoreName = 'Store A' City = 'City A' )
                      ( BookstoreID = other_id BookstoreName = 'Store B' City = 'City B' )
                      ( BookstoreID = master_id BookstoreName = 'Store C' City = 'City C' ) ).
    sql_environment->insert_test_data( stores ).
    DATA(books) = VALUE persisted_books(
      ( BookstoreID = store_id BookID = master_id UnitsInStock = 0 )
      ( BookstoreID = other_id BookID = master_id UnitsInStock = 2 )
      ( BookstoreID = master_id BookID = master_id UnitsInStock = 3 )
      ( BookstoreID = store_id BookID = other_id UnitsInStock = 1 ) ).
    sql_environment->insert_test_data( books ).

    execute_restock( ).
    cl_abap_unit_assert=>assert_initial( failed ).
    success_message ?= reported-bookstore[ 1 ]-%msg.
    cl_abap_unit_assert=>assert_false(
      xsdbool( reported-bookstore[ 1 ]-%msg IS INSTANCE OF zdgd_bookstore_exception ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'ZDGD_BOOKSTORE' act = success_message->if_t100_message~t100key-msgid ).
    cl_abap_unit_assert=>assert_equals(
      exp = '007' act = success_message->if_t100_message~t100key-msgno ).
    cl_abap_unit_assert=>assert_equals( exp = '2' act = success_message->msgv1 ).
    cl_abap_unit_assert=>assert_equals( exp = '10' act = success_message->msgv2 ).
    cl_abap_unit_assert=>assert_equals(
      exp = if_abap_behv_message=>severity-success
      act = reported-bookstore[ 1 ]-%msg->m_severity ).
    READ ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
      ENTITY Book FIELDS ( UnitsInStock )
      WITH VALUE #( FOR book IN books
                    ( BookstoreID = book-BookstoreID BookID = book-BookID
                      %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(actual_books)
      FAILED DATA(read_failed).
    cl_abap_unit_assert=>assert_initial( read_failed ).
    cl_abap_unit_assert=>assert_equals( exp = 4 act = lines( actual_books ) ).
    LOOP AT actual_books INTO DATA(actual_book).
      DATA(original_book) = books[ BookstoreID = actual_book-BookstoreID BookID = actual_book-BookID ].
      cl_abap_unit_assert=>assert_equals(
        exp = COND int1( WHEN original_book-BookID = master_id AND original_book-UnitsInStock < 3
                         THEN 10 ELSE original_book-UnitsInStock )
        act = actual_book-UnitsInStock ).
    ENDLOOP.

    CLEAR: failed, reported.
    execute_restock( ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals(
      exp = if_abap_behv_message=>severity-information
      act = reported-bookstore[ 1 ]-%msg->m_severity ).
  ENDMETHOD.

  METHOD restock_rejects_missing_master.
    execute_restock( ).
    cl_abap_unit_assert=>assert_equals( exp = 'RESTOCK' act = failed-bookstore[ 1 ]-%cid ).
    cl_abap_unit_assert=>assert_true(
      xsdbool( reported-bookstore[ 1 ]-%msg IS INSTANCE OF zdgd_bookstore_exception ) ).
  ENDMETHOD.

  METHOD restock_rejects_initial_book.
    execute_restock( book_id = CONV #( '' ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( failed-bookstore ) ).
  ENDMETHOD.

  METHOD restock_rejects_invalid_target.
    execute_restock( target = 3 ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( failed-bookstore ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = zdgd_bookstore_exception=>invalid_restock_target
      act = CAST zdgd_bookstore_exception( reported-bookstore[ 1 ]-%msg )->if_t100_message~t100key ).
    CLEAR: failed, reported.
    execute_restock( target = 2 ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( failed-bookstore ) ).
  ENDMETHOD.

  METHOD restock_no_assignments.
    given_master( ).
    execute_restock( ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals(
      exp = zdgd_bookstore_exception=>no_restock_candidates
      act = CAST zdgd_bookstore_exception( reported-bookstore[ 1 ]-%msg )->if_t100_message~t100key ).
    cl_abap_unit_assert=>assert_equals(
      exp = if_abap_behv_message=>severity-information
      act = reported-bookstore[ 1 ]-%msg->m_severity ).
  ENDMETHOD.

  METHOD restock_zero_threshold.
    given_master( ).
    DATA(books) = VALUE persisted_books(
      ( BookstoreID = store_id BookID = master_id UnitsInStock = 0 ) ).
    sql_environment->insert_test_data( books ).
    execute_restock( threshold = 0 ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals(
      exp = if_abap_behv_message=>severity-information
      act = reported-bookstore[ 1 ]-%msg->m_severity ).
  ENDMETHOD.

  METHOD restock_empty_requests.
    cut->restockbook( EXPORTING keys = VALUE #( )
                      CHANGING mapped = mapped failed = failed reported = reported ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
  ENDMETHOD.

  METHOD restock_authorization.
    DATA authorization TYPE STRUCTURE FOR GLOBAL AUTHORIZATION RESULT zdgd_i_bookstore\\Bookstore.
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %action-ReStockBook = if_abap_behv=>mk-on )
      CHANGING result = authorization ).
    cl_abap_unit_assert=>assert_equals(
      exp = if_abap_behv=>auth-allowed act = authorization-%action-ReStockBook ).
  ENDMETHOD.

  METHOD assert_restock_defaults.
    DATA defaults TYPE TABLE FOR FUNCTION RESULT zdgd_i_bookstore\\Bookstore~GetDefaultsForRestockBook.
    cut->getdefaultsforrestockbook(
      EXPORTING keys = VALUE #( ( %cid = 'FIRST' ) ( %cid = 'SECOND' ) )
      CHANGING result = defaults ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( defaults ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'FIRST' act = defaults[ 1 ]-%cid ).
    cl_abap_unit_assert=>assert_equals( exp = 'SECOND' act = defaults[ 2 ]-%cid ).
    LOOP AT defaults INTO DATA(default).
      cl_abap_unit_assert=>assert_equals( exp = expected_book_id act = default-%param-BookID ).
      cl_abap_unit_assert=>assert_equals( exp = 3 act = default-%param-StockThreshold ).
      cl_abap_unit_assert=>assert_equals( exp = 10 act = default-%param-TargetStock ).
    ENDLOOP.
  ENDMETHOD.

  METHOD defaults_aggregate_stock.
    DATA(books) = VALUE persisted_books(
      ( BookstoreID = store_id BookID = master_id UnitsInStock = 1 )
      ( BookstoreID = other_id BookID = master_id UnitsInStock = 2 )
      ( BookstoreID = store_id BookID = other_id UnitsInStock = 0 ) ).
    sql_environment->insert_test_data( books ).

    assert_restock_defaults( expected_book_id = master_id ).
  ENDMETHOD.

  METHOD defaults_threshold_boundary.
    DATA(books) = VALUE persisted_books(
      ( BookstoreID = store_id BookID = master_id UnitsInStock = 2 )
      ( BookstoreID = store_id BookID = other_id UnitsInStock = 3 )
      ( BookstoreID = other_id BookID = other_id UnitsInStock = 3 )
      ( BookstoreID = master_id BookID = other_id UnitsInStock = 11 ) ).
    sql_environment->insert_test_data( books ).

    assert_restock_defaults( expected_book_id = master_id ).
  ENDMETHOD.

  METHOD defaults_tie_by_book_id.
    DATA(books) = VALUE persisted_books(
      ( BookstoreID = store_id BookID = other_id UnitsInStock = 1 )
      ( BookstoreID = store_id BookID = master_id UnitsInStock = 1 ) ).
    sql_environment->insert_test_data( books ).

    assert_restock_defaults( expected_book_id = master_id ).
  ENDMETHOD.

  METHOD defaults_empty_inventory.
    assert_restock_defaults( ).
  ENDMETHOD.

  METHOD defaults_no_candidate.
    DATA(books) = VALUE persisted_books(
      ( BookstoreID = store_id BookID = master_id UnitsInStock = 3 )
      ( BookstoreID = store_id BookID = other_id UnitsInStock = 10 ) ).
    sql_environment->insert_test_data( books ).

    assert_restock_defaults( ).
  ENDMETHOD.

  METHOD defaults_large_total.
    DATA(books) = VALUE persisted_books(
      FOR store_index = 1 UNTIL store_index > 30
      ( BookstoreID = CONV #( store_index ) BookID = master_id UnitsInStock = 0 ) ).
    APPEND VALUE #( BookstoreID = store_id BookID = other_id UnitsInStock = 0 ) TO books.
    sql_environment->insert_test_data( books ).

    assert_restock_defaults( expected_book_id = master_id ).
  ENDMETHOD.

  METHOD defaults_empty_requests.
    DATA defaults TYPE TABLE FOR FUNCTION RESULT zdgd_i_bookstore\\Bookstore~GetDefaultsForRestockBook.
    cut->getdefaultsforrestockbook(
      EXPORTING keys = VALUE #( )
      CHANGING result = defaults ).

    cl_abap_unit_assert=>assert_initial( defaults ).
  ENDMETHOD.

  METHOD resolves_semantic_key.
    given_master( ).
    given_request( ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mapped-book ) ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( ).
  ENDMETHOD.

  METHOD precheck_request_duplicates.
    given_master( ).
    given_request( ).
    given_request( cid = 'DUPLICATE' ).

    cut->precheck_cba_books( EXPORTING entities = requests
                             CHANGING  failed   = failed
                                       reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( reported-book ) ).
    LOOP AT reported-book INTO DATA(error).
      cl_abap_unit_assert=>assert_true( xsdbool( error-%msg IS INSTANCE OF zdgd_bookstore_exception ) ).
      cl_abap_unit_assert=>assert_equals( exp = zdgd_bookstore_exception=>request_contains_duplicates
                                          act = CAST if_t100_message( error-%msg )->t100key ).
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_persisted_duplicate.
    given_master( ).
    sql_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = store_id BookID = master_id ) ) ).
    given_request( ).

    cut->precheck_cba_books( EXPORTING entities = requests
                           CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = zdgd_bookstore_exception=>book_already_exists
        act = CAST if_t100_message( reported-book[ 1 ]-%msg )->t100key ).
  ENDMETHOD.

  METHOD precheck_missing_master.
    given_request( ).

    cut->precheck_cba_books( EXPORTING entities = requests
                             CHANGING  failed   = failed
                                       reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = zdgd_bookstore_exception=>book_not_in_master_data
                                        act = CAST if_t100_message( reported-book[ 1 ]-%msg )->t100key ).
  ENDMETHOD.

  METHOD precheck_active_ignored.
    given_master( ).
    sql_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = store_id BookID = master_id ) ) ).
    given_request( is_draft = if_abap_behv=>mk-off ).

    cut->precheck_cba_books( EXPORTING entities = requests
                           CHANGING failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_initial( reported-book ).
  ENDMETHOD.

  METHOD helper_request_duplicates.
    DATA(duplicates) = lcl_book_validation=>get_instance( )->find_request_duplicates(
      VALUE lif_book_validation=>request_candidates(
        ( cid = 'FIRST' BookstoreID = store_id BookID = master_id )
        ( cid = 'SECOND' BookstoreID = store_id BookID = master_id )
        ( cid = 'OTHER_STORE' BookstoreID = other_id BookID = master_id ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( duplicates ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( duplicates[ cid = 'FIRST' ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( duplicates[ cid = 'SECOND' ] ) ) ).
  ENDMETHOD.

  METHOD helper_parent_refs_distinct.
    DATA(duplicates) = lcl_book_validation=>get_instance( )->find_request_duplicates(
      VALUE lif_book_validation=>request_candidates(
        ( cid = 'STORE_A_BOOK' parent_cid = 'STORE_A' BookID = master_id )
        ( cid = 'STORE_B_BOOK' parent_cid = 'STORE_B' BookID = master_id ) ) ).

    cl_abap_unit_assert=>assert_initial( duplicates ).
  ENDMETHOD.

  METHOD helper_empty_request.
    DATA(duplicates) = lcl_book_validation=>get_instance( )->find_request_duplicates( VALUE #( ) ).

    cl_abap_unit_assert=>assert_initial( duplicates ).
  ENDMETHOD.

  METHOD preserves_matching_id.
    given_master( ).
    given_request( book_id = master_id is_draft = if_abap_behv=>mk-off ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( is_draft = if_abap_behv=>mk-off ).
  ENDMETHOD.

  METHOD maps_supplied_id_from_master.
    given_master( ).
    given_request( book_id = other_id ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( ).
  ENDMETHOD.

  METHOD rejects_missing_master.
    given_request( ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( mapped ).
    assert_numbering_failure( ).
  ENDMETHOD.

  METHOD rejects_draft_only_master.
    sql_environment->insert_test_data(
        VALUE draft_books( ( BookID = master_id BookName = 'Book A' Author = 'Author A' Language = 'E' ) ) ).
    given_request( ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( mapped ).
    assert_numbering_failure( ).
  ENDMETHOD.

  METHOD active_failure_keeps_id.
    given_request( book_id  = other_id
                   is_draft = if_abap_behv=>mk-off ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( mapped ).
    assert_numbering_failure( book_id  = other_id
                              is_draft = if_abap_behv=>mk-off ).
  ENDMETHOD.

  METHOD preserves_existing_responses.
    given_master( ).
    given_request( ).
    mapped-book = VALUE #( ( %cid = 'PREVIOUS' BookstoreID = store_id BookID = other_id ) ).
    failed-book = VALUE #( ( %cid = 'FAILED' ) ).
    reported-book = VALUE #( ( %cid = 'REPORTED' ) ).

    cut->earlynumbering_cba_books( EXPORTING entities = requests
                                  CHANGING mapped = mapped failed = failed reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mapped-book ) ).
    assert_mapping( cid = 'PREVIOUS' book_id = other_id is_draft = if_abap_behv=>mk-off ).
    assert_mapping( ).
    cl_abap_unit_assert=>assert_equals( exp = 'FAILED' act = failed-book[ 1 ]-%cid ).
    cl_abap_unit_assert=>assert_equals( exp = 'REPORTED' act = reported-book[ 1 ]-%cid ).
  ENDMETHOD.

  METHOD matches_all_semantic_fields.
    given_master( ).
    given_master( book_id = other_id language = 'D' ).
    given_request( language = 'D' ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( failed ).
    assert_mapping( book_id = other_id ).

    CLEAR requests.
    given_request( author = 'Other Author' ).
    when_numbered( ).
    cl_abap_unit_assert=>assert_initial( mapped ).
    assert_numbering_failure( ).

    CLEAR requests.
    given_request( book_name = 'Other Book' ).
    when_numbered( ).
    cl_abap_unit_assert=>assert_initial( mapped ).
    assert_numbering_failure( ).
  ENDMETHOD.

  METHOD handles_mixed_batch.
    given_master( ).
    given_request( ).
    given_request( cid = 'MISSING' book_name = 'Missing Book' ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mapped-book ) ).
    assert_mapping( ).
    assert_numbering_failure( cid = 'MISSING' ).
  ENDMETHOD.

  METHOD maps_duplicate_requests.
    given_master( ).
    given_request( ).
    given_request( cid = 'DUPLICATE' ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mapped-book ) ).
    assert_mapping( ).
    assert_mapping( cid = 'DUPLICATE' ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
  ENDMETHOD.

  METHOD maps_existing_assignment.
    given_master( ).
    sql_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = store_id BookID = master_id ) ) ).
    given_request( ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( ).
  ENDMETHOD.

  METHOD allows_different_book_in_store.
    given_master( ).
    given_master( book_id   = other_id
                  book_name = 'Book B'
                  author    = 'Author B' ).
    sql_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = store_id BookID = master_id ) ) ).
    given_request( book_name = 'Book B'
                   author    = 'Author B' ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( book_id = other_id ).
  ENDMETHOD.

  METHOD allows_book_in_other_store.
    given_master( ).
    given_request( ).
    given_request( cid = 'OTHER_STORE' bookstore_id = other_id ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mapped-book ) ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( ).
    assert_mapping( cid = 'OTHER_STORE' bookstore_id = other_id ).
  ENDMETHOD.

  METHOD existing_other_store_passes.
    given_master( ).
    sql_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = other_id BookID = master_id ) ) ).
    given_request( ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
    assert_mapping( ).
  ENDMETHOD.

  METHOD distinguishes_parent_refs.
    given_master( ).
    given_request( bookstore_id = CONV #( '' ) parent_cid = 'STORE_A' ).
    given_request( cid = 'OTHER_PARENT' bookstore_id = CONV #( '' ) parent_cid = 'STORE_B' ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mapped-book ) ).
    cl_abap_unit_assert=>assert_initial( failed ).
    assert_mapping( bookstore_id = CONV #( '' ) ).
    assert_mapping( cid = 'OTHER_PARENT' bookstore_id = CONV #( '' ) ).
  ENDMETHOD.

  METHOD empty_requests.
    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( mapped ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
  ENDMETHOD.

  METHOD empty_targets.
    requests = VALUE #( ( BookstoreID = store_id %is_draft = if_abap_behv=>mk-on ) ).

    when_numbered( ).

    cl_abap_unit_assert=>assert_initial( mapped ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
  ENDMETHOD.

  METHOD given_master.
    sql_environment->insert_test_data(
        VALUE master_books( ( BookID = book_id BookName = book_name Author = author Language = language ) ) ).
  ENDMETHOD.

  METHOD given_request.
    APPEND VALUE #( BookstoreID = bookstore_id
                    %cid_ref = parent_cid
                    %is_draft = is_draft
                    %target = VALUE #( ( %cid = cid
                                         %is_draft = is_draft
                                         BookID = book_id
                                         BookName = book_name
                                         Author = author
                                         Language = language
                                         %control-BookName = if_abap_behv=>mk-on
                                         %control-Author = if_abap_behv=>mk-on
                                         %control-Language = if_abap_behv=>mk-on ) ) ) TO requests.
  ENDMETHOD.

  METHOD when_numbered.
    CLEAR: mapped, failed, reported.
    cut->earlynumbering_cba_books( EXPORTING entities = requests
                                  CHANGING mapped = mapped failed = failed reported = reported ).
  ENDMETHOD.

  METHOD assert_mapping.
    DATA(found) = abap_false.
    LOOP AT mapped-book INTO DATA(book) USING KEY cid WHERE %cid = cid.
      cl_abap_unit_assert=>assert_false( found ).
      found = abap_true.
      cl_abap_unit_assert=>assert_equals( exp = bookstore_id act = book-BookstoreID ).
      cl_abap_unit_assert=>assert_equals( exp = book_id act = book-BookID ).
      cl_abap_unit_assert=>assert_equals( exp = is_draft act = book-%is_draft ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( found ).
  ENDMETHOD.

  METHOD assert_numbering_failure.
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( failed-book ) ).
    DATA(failure) = failed-book[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = cid act = failure-%cid ).
    cl_abap_unit_assert=>assert_equals( exp = store_id act = failure-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = book_id act = failure-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = is_draft act = failure-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>cause-unspecific act = failure-%fail-cause ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( reported-book ) ).
    DATA(error) = reported-book[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = cid act = error-%cid ).
    cl_abap_unit_assert=>assert_equals( exp = store_id act = error-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = book_id act = error-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = is_draft act = error-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on act = error-%element-BookName ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on act = error-%element-Author ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on act = error-%element-Language ).
    cl_abap_unit_assert=>assert_true( xsdbool( error-%msg IS INSTANCE OF zdgd_bookstore_exception ) ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv_message=>severity-error act = error-%msg->m_severity ).
    cl_abap_unit_assert=>assert_equals(
        exp = zdgd_bookstore_exception=>book_not_in_master_data
        act = CAST if_t100_message( error-%msg )->t100key ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( mapped-book[ KEY cid %cid = cid ] ) ) ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_book_master_data DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES master_books    TYPE STANDARD TABLE OF zdgd_i_bookmasterdata WITH EMPTY KEY.
    TYPES draft_books     TYPE STANDARD TABLE OF zdgd_i_bookmasterdata_d WITH EMPTY KEY.
    TYPES persisted_books TYPE STANDARD TABLE OF zdgd_i_book WITH EMPTY KEY.
    CONSTANTS master_book_id  TYPE sysuuid_x16 VALUE '00000000000000000000000000000002'.
    CONSTANTS missing_book_id TYPE sysuuid_x16 VALUE '00000000000000000000000000000003'.

    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.
    CLASS-DATA bo_test_environment  TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA cut              TYPE REF TO lhc_book.
    DATA book_keys        TYPE TABLE FOR READ IMPORT zdgd_i_bookstore\\Book.
    DATA failed           TYPE RESPONSE FOR FAILED LATE zdgd_i_bookstore.
    DATA reported         TYPE RESPONSE FOR REPORTED LATE zdgd_i_bookstore.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    METHODS active_master_passes           FOR TESTING.
    METHODS missing_master_fails           FOR TESTING.
    METHODS initial_id_fails               FOR TESTING.
    METHODS mixed_batch_fails_only_missing FOR TESTING.
    METHODS same_book_in_two_stores_passes FOR TESTING.
    METHODS draft_only_master_fails        FOR TESTING.
    METHODS draft_identity_is_preserved    FOR TESTING.
    METHODS empty_input_passes             FOR TESTING.
    METHODS nonexistent_child_is_skipped   FOR TESTING.
    METHODS corrected_reference_clears_msg FOR TESTING.
    METHODS matching_details_pass          FOR TESTING.
    METHODS wrong_name_fails               FOR TESTING.
    METHODS wrong_author_fails             FOR TESTING.
    METHODS wrong_language_fails           FOR TESTING.
    METHODS all_details_wrong_fail         FOR TESTING.
    METHODS blank_details_fail             FOR TESTING.
    METHODS corrected_details_clear_msg    FOR TESTING.
    METHODS mixed_details_batch            FOR TESTING.
    METHODS helper_mixed_master_batch      FOR TESTING.
    METHODS helper_empty_master_batch      FOR TESTING.
    METHODS book_duplicate_fails           FOR TESTING.
    METHODS mixed_duplicate_batch          FOR TESTING.
    METHODS book_other_store_passes        FOR TESTING.
    METHODS different_book_passes FOR TESTING.
    METHODS draft_details_mismatch         FOR TESTING.
    METHODS new_draft_language_changed     FOR TESTING.

    METHODS given_book
      IMPORTING book_id   TYPE sysuuid_x16
                is_draft  TYPE abp_behv_flag   DEFAULT if_abap_behv=>mk-off
                book_name TYPE zdgd_bookname   OPTIONAL
                author    TYPE zdgd_bookauthor OPTIONAL
                !language TYPE spras           OPTIONAL.

    METHODS given_master_details.

    METHODS assert_mismatch
      IMPORTING name_flag     TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
                author_flag   TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off
                language_flag TYPE abp_behv_flag DEFAULT if_abap_behv=>mk-off.

    METHODS zero_id_draft_targets_fields FOR TESTING.
    METHODS when_validated.
    METHODS when_duplicate_checked.

    METHODS count_errors                 RETURNING VALUE(result) TYPE i.
ENDCLASS.


CLASS ltcl_book_master_data IMPLEMENTATION.
  METHOD helper_mixed_master_batch.
    given_master_details( ).
    DATA(invalid_books) = lcl_book_validation=>get_instance( )->find_invalid_master_data(
        VALUE #( ( BookID = master_book_id BookName = 'Master Book' Author = 'Master Author' Language = 'E' )
                 ( BookID = master_book_id BookName = 'Master Book' Author = 'Wrong Author' Language = 'E' )
                 ( BookID = master_book_id BookName = 'Master Book' Author = 'Wrong Author' Language = 'E' )
                 ( BookID = missing_book_id BookName = 'Missing Book' Author = 'Missing Author' Language = 'E' ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( invalid_books ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( invalid_books[
        BookID = master_book_id BookName = 'Master Book' Author = 'Master Author' Language = 'E' ] ) ) ).
    DATA(mismatch) = invalid_books[
        BookID = master_book_id BookName = 'Master Book' Author = 'Wrong Author' Language = 'E' ].
    cl_abap_unit_assert=>assert_false( mismatch-name_mismatch ).
    cl_abap_unit_assert=>assert_true( mismatch-author_mismatch ).
    cl_abap_unit_assert=>assert_false( mismatch-language_mismatch ).
    DATA(missing) = invalid_books[
        BookID = missing_book_id BookName = 'Missing Book' Author = 'Missing Author' Language = 'E' ].
    cl_abap_unit_assert=>assert_true( missing-name_mismatch ).
    cl_abap_unit_assert=>assert_true( missing-author_mismatch ).
    cl_abap_unit_assert=>assert_true( missing-language_mismatch ).
  ENDMETHOD.

  METHOD helper_empty_master_batch.
    DATA(invalid_books) = lcl_book_validation=>get_instance( )->find_invalid_master_data( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( invalid_books ).
  ENDMETHOD.

  METHOD class_setup.
    sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZDGD_I_BOOKMASTERDATA' )
                                                                                          ( 'ZDGD_I_BOOKMASTERDATA_D' )
                                                                                          ( 'ZDGD_I_BOOK' ) ) ).
    DATA(environment_config) = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                                   )->set_bdef_dependencies( VALUE #( ( 'ZDGD_I_BOOKSTORE' ) ) ).
    environment_config = environment_config->handle_draft( VALUE #( ( 'ZDGD_I_BOOKSTORE' ) ) ).
    bo_test_environment = cl_botd_txbufdbl_bo_test_env=>create( environment_config = environment_config ).
  ENDMETHOD.

  METHOD class_teardown.
    bo_test_environment->destroy( ).
    sql_test_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    CREATE OBJECT cut FOR TESTING.
    CLEAR: book_keys,
           failed,
          reported.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    bo_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD active_master_passes.
    sql_test_environment->insert_test_data( VALUE master_books( ( BookID = master_book_id ) ) ).
    given_book( master_book_id ).

    when_validated( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( reported-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_MASTER_DATA'
                                        act = reported-book[ 1 ]-%state_area ).
  ENDMETHOD.

  METHOD missing_master_fails.
    given_book( missing_book_id ).

    when_validated( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = failed-book[ 1 ]-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
    DATA(error) = reported-book[ 2 ].
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = error-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-BookstoreID
                                        act = error-%path-Bookstore-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%is_draft
                                        act = error-%path-Bookstore-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_MASTER_DATA'
                                        act = error-%state_area ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-BookName ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-Author ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-Language ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-off
                                        act = error-%element-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv_message=>severity-error
                                        act = error-%msg->m_severity ).
  ENDMETHOD.

  METHOD initial_id_fails.
    given_book( CONV sysuuid_x16( '' ) ).

    when_validated( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_initial( failed-book[ 1 ]-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
  ENDMETHOD.

  METHOD mixed_batch_fails_only_missing.
    sql_test_environment->insert_test_data( VALUE master_books( ( BookID = master_book_id ) ) ).
    given_book( master_book_id ).
    given_book( missing_book_id ).

    when_validated( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = missing_book_id
                                        act = failed-book[ 1 ]-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
  ENDMETHOD.

  METHOD same_book_in_two_stores_passes.
    sql_test_environment->insert_test_data( VALUE master_books( ( BookID = master_book_id ) ) ).
    given_book( master_book_id ).
    given_book( master_book_id ).

    when_validated( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( reported-book ) ).
  ENDMETHOD.

  METHOD draft_only_master_fails.
    sql_test_environment->insert_test_data( VALUE draft_books( ( BookID = missing_book_id ) ) ).
    given_book( missing_book_id ).

    when_validated( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
  ENDMETHOD.

  METHOD draft_identity_is_preserved.
    given_book( book_id  = missing_book_id
                is_draft = if_abap_behv=>mk-on ).

    when_validated( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = failed-book[ 1 ]-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = reported-book[ 2 ]-%tky ).
  ENDMETHOD.

  METHOD empty_input_passes.
    when_validated( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_initial( reported-book ).
  ENDMETHOD.

  METHOD nonexistent_child_is_skipped.
    book_keys = VALUE #( ( BookstoreID = master_book_id
                           BookID      = missing_book_id
                           %is_draft   = if_abap_behv=>mk-off ) ).

    when_validated( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_initial( reported-book ).
  ENDMETHOD.

  METHOD corrected_reference_clears_msg.
    given_book( missing_book_id ).
    when_validated( ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).

    sql_test_environment->insert_test_data( VALUE master_books( ( BookID = missing_book_id ) ) ).
    when_validated( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( reported-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_MASTER_DATA'
                                        act = reported-book[ 1 ]-%state_area ).
  ENDMETHOD.

  METHOD matching_details_pass.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'E' ).
    when_validated( ).
    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
  ENDMETHOD.

  METHOD wrong_name_fails.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Wrong Book'
                author    = 'Master Author'
                language  = 'E' ).
    when_validated( ).
    assert_mismatch( name_flag = if_abap_behv=>mk-on ).
  ENDMETHOD.

  METHOD wrong_author_fails.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Master Book'
                author    = 'Wrong Author'
                language  = 'E' ).
    when_validated( ).
    assert_mismatch( author_flag = if_abap_behv=>mk-on ).
  ENDMETHOD.

  METHOD wrong_language_fails.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'F' ).
    when_validated( ).
    assert_mismatch( language_flag = if_abap_behv=>mk-on ).
  ENDMETHOD.

  METHOD all_details_wrong_fail.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Wrong Book'
                author    = 'Wrong Author'
                language  = 'F' ).
    when_validated( ).
    assert_mismatch( name_flag     = if_abap_behv=>mk-on
                     author_flag   = if_abap_behv=>mk-on
                     language_flag = if_abap_behv=>mk-on ).
  ENDMETHOD.

  METHOD blank_details_fail.
    given_master_details( ).
    given_book( master_book_id ).
    when_validated( ).
    assert_mismatch( name_flag     = if_abap_behv=>mk-on
                     author_flag   = if_abap_behv=>mk-on
                     language_flag = if_abap_behv=>mk-on ).
  ENDMETHOD.

  METHOD corrected_details_clear_msg.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Wrong Book'
                author    = 'Master Author'
                language  = 'E' ).
    when_validated( ).
    assert_mismatch( name_flag = if_abap_behv=>mk-on ).

    MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
           ENTITY Book UPDATE FIELDS ( BookName )
           WITH VALUE #( ( %tky = book_keys[ 1 ]-%tky BookName = 'Master Book' ) )
           FAILED DATA(update_failed).
    cl_abap_unit_assert=>assert_initial( update_failed ).
    when_validated( ).
    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( reported-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_MASTER_DATA'
                                        act = reported-book[ 1 ]-%state_area ).
  ENDMETHOD.

  METHOD mixed_details_batch.
    given_master_details( ).
    given_book( book_id   = master_book_id
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'E' ).
    given_book( book_id   = master_book_id
                book_name = 'Master Book'
                author    = 'Wrong Author'
                language  = 'E' ).
    when_validated( ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 2 ]-%tky
                                        act = failed-book[ 1 ]-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = reported-book[ 3 ]-%element-Author ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 2 ]-BookstoreID
                                        act = reported-book[ 3 ]-%path-Bookstore-BookstoreID ).
  ENDMETHOD.

  METHOD different_book_passes.
    sql_test_environment->insert_test_data(
        VALUE master_books( ( BookID = master_book_id
                              BookName = 'Master Book'
                              Author = 'Master Author'
                              Language = 'E' )
                            ( BookID = missing_book_id
                              BookName = 'Different Book'
                              Author = 'Different Author'
                              Language = 'E' ) ) ).
    given_book( book_id   = missing_book_id
                book_name = 'Different Book'
                author    = 'Different Author'
                language  = 'E' ).
    sql_test_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = book_keys[ 1 ]-BookstoreID
                                 BookID      = master_book_id ) ) ).

    when_duplicate_checked( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
  ENDMETHOD.

  METHOD draft_details_mismatch.
    given_master_details( ).
    given_book( book_id   = master_book_id
                is_draft  = if_abap_behv=>mk-on
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'E' ).

    MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
           ENTITY Book UPDATE FIELDS ( Language )
           WITH VALUE #( ( %tky = book_keys[ 1 ]-%tky Language = 'P' ) )
           FAILED DATA(update_failed).
    cl_abap_unit_assert=>assert_initial( update_failed ).

    when_validated( ).
    assert_mismatch( language_flag = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = failed-book[ 1 ]-%is_draft ).
  ENDMETHOD.

  METHOD new_draft_language_changed.
    given_master_details( ).
    given_book( book_id   = master_book_id
                is_draft  = if_abap_behv=>mk-on
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'E' ).
    when_validated( ).
    cl_abap_unit_assert=>assert_initial( failed-book ).

    MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
           ENTITY Book UPDATE FIELDS ( Language )
           WITH VALUE #( ( %tky = book_keys[ 1 ]-%tky Language = 'S' ) )
           FAILED DATA(update_failed).
    cl_abap_unit_assert=>assert_initial( update_failed ).

    when_validated( ).
    assert_mismatch( language_flag = if_abap_behv=>mk-on ).
    DATA(error) = reported-book[ 2 ].
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-BookstoreID
                                        act = error-%path-Bookstore-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%path-Bookstore-%is_draft ).
  ENDMETHOD.

  METHOD zero_id_draft_targets_fields.
    given_master_details( ).
    given_book( book_id   = CONV sysuuid_x16( '' )
                is_draft  = if_abap_behv=>mk-on
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'S' ).

    when_validated( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
    DATA(error) = reported-book[ 2 ].
    cl_abap_unit_assert=>assert_initial( error-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = error-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-BookstoreID
                                        act = error-%path-Bookstore-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%path-Bookstore-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-BookName ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-Author ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-Language ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-off
                                        act = error-%element-BookID ).
  ENDMETHOD.

  METHOD book_duplicate_fails.
    given_master_details( ).
    given_book( master_book_id ).
    sql_test_environment->insert_test_data( VALUE persisted_books( ( BookstoreID = book_keys[ 1 ]-BookstoreID
                                                                     BookID      = master_book_id ) ) ).

    when_duplicate_checked( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = failed-book[ 1 ]-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( reported-book ) ).
    DATA(error) = reported-book[ 2 ].
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_ALREADY_EXISTS'
                                        act = error-%state_area ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-BookstoreID
                                        act = error-%path-Bookstore-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = error-%element-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = '002'
                                        act = CAST if_t100_message( error-%msg )->t100key-msgno ).
  ENDMETHOD.

  METHOD mixed_duplicate_batch.
    given_master_details( ).
    given_book( master_book_id ).
    given_book( master_book_id ).
    sql_test_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = book_keys[ 1 ]-BookstoreID
                                 BookID      = master_book_id ) ) ).

    when_duplicate_checked( ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = failed-book[ 1 ]-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( reported-book ) ).
  ENDMETHOD.

  METHOD book_other_store_passes.
    given_master_details( ).
    given_book( master_book_id ).
    sql_test_environment->insert_test_data(
        VALUE persisted_books( ( BookstoreID = missing_book_id
                                 BookID      = master_book_id ) ) ).

    when_duplicate_checked( ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_errors( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( reported-book ) ).
  ENDMETHOD.

  METHOD given_master_details.
    sql_test_environment->insert_test_data(
        VALUE master_books( ( BookID = master_book_id BookName = 'Master Book' Author = 'Master Author' Language = 'E' ) ) ).
  ENDMETHOD.

  METHOD assert_mismatch.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = failed-book[ 1 ]-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_errors( ) ).
    DATA(error) = reported-book[ 2 ].
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%tky
                                        act = error-%tky ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-BookstoreID
                                        act = error-%path-Bookstore-BookstoreID ).
    cl_abap_unit_assert=>assert_equals( exp = book_keys[ 1 ]-%is_draft
                                        act = error-%path-Bookstore-%is_draft ).
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_MASTER_DATA'
                                        act = error-%state_area ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-off
                                        act = error-%element-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = name_flag
                                        act = error-%element-BookName ).
    cl_abap_unit_assert=>assert_equals( exp = author_flag
                                        act = error-%element-Author ).
    cl_abap_unit_assert=>assert_equals( exp = language_flag
                                        act = error-%element-Language ).
  ENDMETHOD.

  METHOD given_book.
        IF is_draft = if_abap_behv=>mk-on.
          MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
            ENTITY Bookstore
            CREATE FIELDS ( BookstoreName City )
            WITH VALUE #( ( %cid          = 'STORE'
             %is_draft     = is_draft
             BookstoreName = 'Test Store'
             City          = 'Test City' ) )
             CREATE BY \_Books FIELDS ( BookID BookName Author Language )
            WITH VALUE #( ( %cid_ref  = 'STORE'
             %is_draft = is_draft
             %target   = VALUE #( ( %cid      = 'BOOK'
                     %is_draft = is_draft
                     BookID    = book_id
                     BookName  = book_name
                     Author    = author
                     Language  = language ) ) ) )
            MAPPED DATA(mapped_draft)
            FAILED DATA(failed_draft).
          cl_abap_unit_assert=>assert_initial( failed_draft ).
          cl_abap_unit_assert=>assert_equals( exp = 1
                act = lines( mapped_draft-bookstore ) ).
          cl_abap_unit_assert=>assert_equals( exp = 1
                act = lines( mapped_draft-book ) ).

          APPEND VALUE #( BookstoreID = mapped_draft-bookstore[ 1 ]-BookstoreID
           BookID      = mapped_draft-book[ 1 ]-BookID
           %is_draft   = is_draft ) TO book_keys.
          RETURN.
        ENDIF.

    MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
           ENTITY Bookstore
           CREATE FIELDS ( BookstoreName City )
           WITH VALUE #( ( %cid          = 'STORE'
                           %is_draft     = is_draft
                           BookstoreName = 'Test Store'
                           City          = 'Test City' ) )
           MAPPED DATA(mapped_store)
           FAILED DATA(failed_store).
    cl_abap_unit_assert=>assert_initial( failed_store ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( mapped_store-bookstore ) ).

    DATA(store_id) = mapped_store-bookstore[ 1 ]-BookstoreID.
    MODIFY ENTITIES OF zdgd_i_bookstore IN LOCAL MODE
           ENTITY Bookstore
           CREATE BY \_Books FIELDS ( BookID BookName Author Language )
           WITH VALUE #( ( BookstoreID = store_id
                           %is_draft   = is_draft
                           %target     = VALUE #( ( %cid      = 'BOOK'
                                                    %is_draft = is_draft
                                                    BookID    = book_id
                                                    BookName  = book_name
                                                    Author    = author
                                                    Language  = language ) ) ) )
           MAPPED DATA(mapped_book)
           FAILED DATA(failed_book).
    cl_abap_unit_assert=>assert_initial( failed_book ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( mapped_book-book ) ).

    APPEND VALUE #( BookstoreID = store_id
                    BookID      = book_id
                    %is_draft   = is_draft ) TO book_keys.
  ENDMETHOD.

  METHOD when_validated.
    CLEAR: failed,
           reported.
    cut->exists_in_master_data( EXPORTING keys     = CORRESPONDING #( book_keys )
                                CHANGING  failed   = failed
                                          reported = reported ).
  ENDMETHOD.

  METHOD when_duplicate_checked.
    CLEAR: failed,
           reported.
    cut->no_duplicates_in_bookstore( EXPORTING keys     = CORRESPONDING #( book_keys )
                                     CHANGING  failed   = failed
                                               reported = reported ).
  ENDMETHOD.

  METHOD count_errors.
    result = REDUCE #( INIT count = 0
             FOR message IN reported-book WHERE ( %msg IS BOUND )
             NEXT count = count + 1 ).
  ENDMETHOD.
ENDCLASS.

