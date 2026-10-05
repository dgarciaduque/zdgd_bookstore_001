*"* use this source file for your ABAP unit test classes
CLASS ltcl_population DEFINITION DEFERRED.
CLASS zdgd_populate_bookstore DEFINITION LOCAL FRIENDS ltcl_population.

CLASS ltcl_population DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES active_books TYPE STANDARD TABLE OF zdgd_i_bookmasterdata WITH EMPTY KEY.
    TYPES draft_books  TYPE STANDARD TABLE OF zdgd_i_bookmasterdata_d WITH EMPTY KEY.

    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.
    CLASS-DATA bo_test_environment  TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA cut              TYPE REF TO zdgd_populate_bookstore.
    DATA master_data      TYPE active_books.
    DATA bookstore_create TYPE zdgd_populate_bookstore=>bookstore_creates.
    DATA book_link        TYPE zdgd_populate_bookstore=>book_links.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.
    METHODS selects_two_per_language      FOR TESTING.
    METHODS selection_is_deterministic    FOR TESTING.
    METHODS empty_master_data_rejected    FOR TESTING.
    METHODS missing_language_rejected     FOR TESTING.
    METHODS short_language_rejected       FOR TESTING.
    METHODS draft_books_do_not_qualify    FOR TESTING.
    METHODS other_languages_are_ignored   FOR TESTING.
    METHODS initial_master_id_is_ignored  FOR TESTING.
    METHODS payload_counts_and_links      FOR TESTING.
    METHODS payload_copies_master_fields  FOR TESTING.
    METHODS stock_is_deterministic        FOR TESTING.
    METHODS eml_creates_full_payload      FOR TESTING.
    METHODS failed_creation_is_rejected   FOR TESTING.
    METHODS incomplete_mapping_rejected   FOR TESTING.
    METHODS cleanup_deletes_both_levels   FOR TESTING.
    METHODS child_failure_keeps_parents   FOR TESTING.
    METHODS empty_cleanup_is_safe         FOR TESTING.
    METHODS empty_tables_allow_creation   FOR TESTING.
    METHODS active_parent_blocks_creation FOR TESTING.
    METHODS active_child_blocks_creation  FOR TESTING.
    METHODS draft_parent_blocks_creation  FOR TESTING.
    METHODS draft_child_blocks_creation   FOR TESTING.

    METHODS given_masters                 IMPORTING per_language TYPE i DEFAULT 3.
    METHODS given_payload.
ENDCLASS.


CLASS ltcl_population IMPLEMENTATION.
  METHOD class_setup.
    sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZDGD_I_BOOKMASTERDATA' )
                                                                                          ( 'ZDGD_I_BOOKMASTERDATA_D' )
                                                                                          ( 'ZDGD_I_BOOKSTORE' )
                                                                                          ( 'ZDGD_I_BOOK' )
                                                                                          ( 'ZDGD_I_BOOKSTORE_D' )
                                                                                          ( 'ZDGD_I_BOOK_D' ) ) ).
    bo_test_environment = cl_botd_txbufdbl_bo_test_env=>create(
                              environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                               )->set_bdef_dependencies( VALUE #( ( 'ZDGD_I_BOOKSTORE' ) ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    bo_test_environment->destroy( ).
    sql_test_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    cut = NEW #( ).
    CLEAR: master_data,
           bookstore_create,
           book_link.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    bo_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD selects_two_per_language.
    given_masters( ).
    cut->select_master_books( IMPORTING books             = DATA(books)
                                        shortage_language = DATA(shortage) ).

    cl_abap_unit_assert=>assert_initial( shortage ).
    cl_abap_unit_assert=>assert_equals( exp = 10
                                        act = lines( books ) ).
    DATA(languages) = VALUE zdgd_populate_bookstore=>language_keys( ( 'E' )
                                                                    ( 'S' )
                                                                    ( 'P' )
                                                                    ( 'I' )
                                                                    ( 'F' ) ).
    LOOP AT languages INTO DATA(language_key).
      DATA(language_count) = REDUCE i( INIT count = 0
       FOR book IN books WHERE ( Language = language_key ) NEXT count = count + 1 ).
      cl_abap_unit_assert=>assert_equals( exp = 2
                                          act = language_count ).
    ENDLOOP.
  ENDMETHOD.

  METHOD selection_is_deterministic.
    given_masters( ).
    cut->select_master_books( IMPORTING books = DATA(first_selection) ).
    cut->select_master_books( IMPORTING books = DATA(second_selection) ).

    cl_abap_unit_assert=>assert_equals( exp = first_selection
                                        act = second_selection ).
    SORT master_data BY BookID.
    LOOP AT first_selection INTO DATA(book).
      DATA(smaller_count) = REDUCE i( INIT count = 0 FOR master IN master_data
       WHERE ( Language = book-Language AND BookID < book-BookID ) NEXT count = count + 1 ).
      cl_abap_unit_assert=>assert_number_between( lower  = 0
                                                  upper  = 1
                                                  number = smaller_count ).
    ENDLOOP.
  ENDMETHOD.

  METHOD empty_master_data_rejected.
    cut->select_master_books( IMPORTING books             = DATA(books)
                                        shortage_language = DATA(shortage) ).

    cl_abap_unit_assert=>assert_initial( books ).
    cl_abap_unit_assert=>assert_equals( exp = 'E'
                                        act = shortage ).
  ENDMETHOD.

  METHOD missing_language_rejected.
    given_masters( ).
    sql_test_environment->clear_doubles( ).
    DELETE master_data WHERE Language = 'F'.
    sql_test_environment->insert_test_data( master_data ).

    cut->select_master_books( IMPORTING books             = DATA(books)
                                        shortage_language = DATA(shortage) ).

    cl_abap_unit_assert=>assert_initial( books ).
    cl_abap_unit_assert=>assert_equals( exp = 'F'
                                        act = shortage ).
  ENDMETHOD.

  METHOD short_language_rejected.
    given_masters( ).
    sql_test_environment->clear_doubles( ).
    DATA(portuguese) = master_data[ Language = 'P' ].
    DELETE master_data WHERE Language = 'P'.
    APPEND portuguese TO master_data.
    sql_test_environment->insert_test_data( master_data ).

    cut->select_master_books( IMPORTING books             = DATA(books)
                                        shortage_language = DATA(shortage) ).

    cl_abap_unit_assert=>assert_initial( books ).
    cl_abap_unit_assert=>assert_equals( exp = 'P'
                                        act = shortage ).
  ENDMETHOD.

  METHOD draft_books_do_not_qualify.
    given_masters( ).
    sql_test_environment->clear_doubles( ).
    DATA draft_data TYPE draft_books.
    draft_data = CORRESPONDING #( master_data ).
    sql_test_environment->insert_test_data( draft_data ).
    DELETE master_data WHERE Language = 'I'.
    sql_test_environment->insert_test_data( master_data ).

    cut->select_master_books( IMPORTING books             = DATA(books)
                                        shortage_language = DATA(shortage) ).

    cl_abap_unit_assert=>assert_initial( books ).
    cl_abap_unit_assert=>assert_equals( exp = 'I'
                                        act = shortage ).
  ENDMETHOD.

  METHOD other_languages_are_ignored.
    given_masters( ).
    sql_test_environment->clear_doubles( ).
    APPEND VALUE #( BookID   = '00000000000000000000000000000001'
                    BookName = 'Other language'
                    Language = 'D' ) TO master_data.
    sql_test_environment->insert_test_data( master_data ).

    cut->select_master_books( IMPORTING books = DATA(books) ).

    cl_abap_unit_assert=>assert_equals( exp = 10
                                        act = lines( books ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( books[ Language = 'D' ] ) ) ).
  ENDMETHOD.

  METHOD initial_master_id_is_ignored.
    given_masters( ).
    sql_test_environment->clear_doubles( ).
    APPEND VALUE #( Language = 'E' ) TO master_data.
    sql_test_environment->insert_test_data( master_data ).

    cut->select_master_books( IMPORTING books = DATA(books) ).

    cl_abap_unit_assert=>assert_equals( exp = 10
                                        act = lines( books ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( books[ BookID = CONV sysuuid_x16( '' ) ] ) ) ).
  ENDMETHOD.

  METHOD payload_counts_and_links.
    given_payload( ).
    cl_abap_unit_assert=>assert_equals( exp = 20
                                        act = lines( bookstore_create ) ).
    cl_abap_unit_assert=>assert_equals( exp = 20
                                        act = lines( book_link ) ).
    DATA correlation_ids TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA(total_books) = 0.

    LOOP AT bookstore_create INTO DATA(store).
      INSERT store-%cid INTO TABLE correlation_ids.
      cl_abap_unit_assert=>assert_subrc( ).
      cl_abap_unit_assert=>assert_not_initial( store-BookstoreName ).
      cl_abap_unit_assert=>assert_not_initial( store-City ).
      DATA(link) = book_link[ KEY cid COMPONENTS %cid_ref = store-%cid ].
      cl_abap_unit_assert=>assert_equals( exp = 10
                                          act = lines( link-%target ) ).
      " TODO: variable is assigned but never used (ABAP cleaner)
      DATA book_ids TYPE HASHED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
      CLEAR book_ids.
      LOOP AT link-%target INTO DATA(book).
        INSERT book-%cid INTO TABLE correlation_ids.
        cl_abap_unit_assert=>assert_subrc( ).
        INSERT book-BookID INTO TABLE book_ids.
        cl_abap_unit_assert=>assert_subrc( ).
        total_books += 1.
      ENDLOOP.
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals( exp = 200
                                        act = total_books ).
    cl_abap_unit_assert=>assert_equals( exp = 220
                                        act = lines( correlation_ids ) ).
    cl_abap_unit_assert=>assert_equals( exp = `The Reading Nook`
                                        act = bookstore_create[ 1 ]-BookstoreName ).
    cl_abap_unit_assert=>assert_equals( exp = `Chicago`
                                        act = bookstore_create[ 20 ]-City ).
  ENDMETHOD.

  METHOD payload_copies_master_fields.
    given_payload( ).
    LOOP AT book_link INTO DATA(link).
      DATA(languages) = VALUE zdgd_populate_bookstore=>language_keys( ( 'E' )
                                                                      ( 'S' )
                                                                      ( 'P' )
                                                                      ( 'I' )
                                                                      ( 'F' ) ).
      LOOP AT languages INTO DATA(language_key).
        DATA(language_count) = REDUCE i( INIT count = 0
         FOR child IN link-%target WHERE ( Language = language_key ) NEXT count = count + 1 ).
        cl_abap_unit_assert=>assert_equals( exp = 2
                                            act = language_count ).
      ENDLOOP.
      LOOP AT link-%target INTO DATA(book).
        DATA(master) = master_data[ BookID = book-BookID ].
        cl_abap_unit_assert=>assert_equals( exp = master-BookName
                                            act = book-BookName ).
        cl_abap_unit_assert=>assert_equals( exp = master-Author
                                            act = book-Author ).
        cl_abap_unit_assert=>assert_equals( exp = master-Language
                                            act = book-Language ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD stock_is_deterministic.
    given_payload( ).
    LOOP AT book_link INTO DATA(link).
      LOOP AT link-%target INTO DATA(book).
        DATA(position) = sy-tabix.
        cl_abap_unit_assert=>assert_equals( exp = position * 5
                                            act = book-UnitsInStock ).
        cl_abap_unit_assert=>assert_number_between( lower  = 1
                                                    upper  = 255
                                                    number = book-UnitsInStock ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD eml_creates_full_payload.
    given_payload( ).
    cut->create_entities( EXPORTING bookstore_create = bookstore_create
                                    book_link        = book_link
                          IMPORTING mapped           = DATA(mapped)
                                    failed           = DATA(failed) ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals( exp = 20
                                        act = lines( mapped-bookstore ) ).
    cl_abap_unit_assert=>assert_equals( exp = 200
                                        act = lines( mapped-book ) ).
    cl_abap_unit_assert=>assert_true( cut->is_creation_complete( mapped = mapped
                                                                 failed = failed ) ).

    READ ENTITIES OF zdgd_i_bookstore
         ENTITY Book ALL FIELDS
         WITH VALUE #( FOR mapped_book IN mapped-book
                       ( BookstoreID = mapped_book-BookstoreID BookID = mapped_book-BookID ) )
         RESULT DATA(buffer_books).
    cl_abap_unit_assert=>assert_equals( exp = 200
                                        act = lines( buffer_books ) ).
    LOOP AT buffer_books INTO DATA(book).
      DATA(master) = master_data[ BookID = book-BookID ].
      DATA(expected) = book_link[ 1 ]-%target[ BookID = book-BookID ].
      cl_abap_unit_assert=>assert_equals( exp = master-Language
                                          act = book-Language ).
      cl_abap_unit_assert=>assert_equals( exp = master-BookName
                                          act = book-BookName ).
      cl_abap_unit_assert=>assert_equals( exp = master-Author
                                          act = book-Author ).
      cl_abap_unit_assert=>assert_equals( exp = expected-UnitsInStock
                                          act = book-UnitsInStock ).
    ENDLOOP.
  ENDMETHOD.

  METHOD failed_creation_is_rejected.
    given_payload( ).
    cut->create_entities( EXPORTING bookstore_create = bookstore_create
                                    book_link        = book_link
                          IMPORTING mapped           = DATA(mapped)
                                    failed           = DATA(failed) ).
    cl_abap_unit_assert=>assert_initial( failed ).
    failed-book = VALUE #( ( %cid = 'FAILED_BOOK' ) ).

    cl_abap_unit_assert=>assert_false( cut->is_creation_complete( mapped = mapped
                                                                  failed = failed ) ).
  ENDMETHOD.

  METHOD incomplete_mapping_rejected.
    given_payload( ).
    cut->create_entities( EXPORTING bookstore_create = bookstore_create
                                    book_link        = book_link
                          IMPORTING mapped           = DATA(mapped)
                                    failed           = DATA(failed) ).
    cl_abap_unit_assert=>assert_initial( failed ).
    DELETE mapped-book INDEX 1.

    cl_abap_unit_assert=>assert_false( cut->is_creation_complete( mapped = mapped
                                                                  failed = failed ) ).
    CLEAR mapped-bookstore.
    cl_abap_unit_assert=>assert_false( cut->is_creation_complete( mapped = mapped
                                                                  failed = failed ) ).
  ENDMETHOD.

  METHOD cleanup_deletes_both_levels.
    given_payload( ).
    cut->create_entities( EXPORTING bookstore_create = bookstore_create
                                    book_link        = book_link
                          IMPORTING mapped           = DATA(mapped)
                                    failed           = DATA(create_failed) ).
    cl_abap_unit_assert=>assert_initial( create_failed ).

    cut->delete_existing( EXPORTING books  = CORRESPONDING #( mapped-book )
                                    stores = CORRESPONDING #( mapped-bookstore )
                          IMPORTING failed = DATA(delete_failed) ).
    cl_abap_unit_assert=>assert_initial( delete_failed ).

    READ ENTITIES OF zdgd_i_bookstore
         ENTITY Bookstore ALL FIELDS WITH CORRESPONDING #( mapped-bookstore )
         RESULT DATA(remaining_stores)
         ENTITY Book ALL FIELDS WITH CORRESPONDING #( mapped-book )
         RESULT DATA(remaining_books).
    cl_abap_unit_assert=>assert_initial( remaining_stores ).
    cl_abap_unit_assert=>assert_initial( remaining_books ).
  ENDMETHOD.

  METHOD child_failure_keeps_parents.
    given_payload( ).
    cut->create_entities( EXPORTING bookstore_create = bookstore_create
                                    book_link        = book_link
                          IMPORTING mapped           = DATA(mapped)
                                    failed           = DATA(create_failed) ).
    cl_abap_unit_assert=>assert_initial( create_failed ).
    DATA(missing_books) = VALUE zdgd_populate_bookstore=>book_deletes(
                                    ( BookstoreID = mapped-bookstore[ 1 ]-BookstoreID
                                      BookID      = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF' ) ).

    cut->delete_existing( EXPORTING books  = missing_books
                                    stores = CORRESPONDING #( mapped-bookstore )
                          IMPORTING failed = DATA(delete_failed) ).
    cl_abap_unit_assert=>assert_not_initial( delete_failed-book ).

    READ ENTITIES OF zdgd_i_bookstore
         ENTITY Bookstore ALL FIELDS WITH CORRESPONDING #( mapped-bookstore )
         RESULT DATA(remaining_stores).
    cl_abap_unit_assert=>assert_equals( exp = 20
                                        act = lines( remaining_stores ) ).
  ENDMETHOD.

  METHOD empty_cleanup_is_safe.
    cut->delete_existing( EXPORTING books    = VALUE #( )
                                    stores   = VALUE #( )
                          IMPORTING failed   = DATA(failed)
                                    reported = DATA(reported) ).
    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_initial( reported ).
  ENDMETHOD.

  METHOD empty_tables_allow_creation.
    cl_abap_unit_assert=>assert_false( cut->has_existing_entries( ) ).
  ENDMETHOD.

  METHOD active_parent_blocks_creation.
    DATA stores TYPE STANDARD TABLE OF zdgd_i_bookstore WITH EMPTY KEY.

    stores = VALUE #( ( BookstoreID = '00000000000000000000000000000001' ) ).
    sql_test_environment->insert_test_data( stores ).

    cl_abap_unit_assert=>assert_true( cut->has_existing_entries( ) ).
  ENDMETHOD.

  METHOD active_child_blocks_creation.
    DATA books TYPE STANDARD TABLE OF zdgd_i_book WITH EMPTY KEY.

    books = VALUE #( ( BookstoreID = '00000000000000000000000000000001'
                       BookID      = '00000000000000000000000000000002' ) ).
    sql_test_environment->insert_test_data( books ).

    cl_abap_unit_assert=>assert_true( cut->has_existing_entries( ) ).
  ENDMETHOD.

  METHOD draft_parent_blocks_creation.
    DATA stores TYPE STANDARD TABLE OF zdgd_i_bookstore_d WITH EMPTY KEY.

    stores = VALUE #( ( BookstoreID = '00000000000000000000000000000001' ) ).
    sql_test_environment->insert_test_data( stores ).

    cl_abap_unit_assert=>assert_true( cut->has_existing_entries( ) ).
  ENDMETHOD.

  METHOD draft_child_blocks_creation.
    DATA books TYPE STANDARD TABLE OF zdgd_i_book_d WITH EMPTY KEY.

    books = VALUE #( ( BookstoreID = '00000000000000000000000000000001'
                       BookID      = '00000000000000000000000000000002' ) ).
    sql_test_environment->insert_test_data( books ).

    cl_abap_unit_assert=>assert_true( cut->has_existing_entries( ) ).
  ENDMETHOD.

  METHOD given_masters.
    CLEAR master_data.
    DATA(languages) = VALUE zdgd_populate_bookstore=>language_keys( ( 'E' )
                                                                    ( 'S' )
                                                                    ( 'P' )
                                                                    ( 'I' )
                                                                    ( 'F' ) ).
    LOOP AT languages INTO DATA(language_key).
      DATA(language_index) = sy-tabix.
      DO per_language TIMES.
        DATA(book_id) = CONV sysuuid_x16(
         |{ language_index WIDTH = 2 ALIGN = RIGHT PAD = '0' }{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }0000000000000000000000000000| ).
        APPEND VALUE #( BookID   = book_id
                        BookName = |Book { language_key } { sy-index }|
                        Author   = |Author { sy-index }|
                        Language = language_key ) TO master_data.
      ENDDO.
    ENDLOOP.
    SORT master_data BY BookID DESCENDING.
    sql_test_environment->insert_test_data( master_data ).
  ENDMETHOD.

  METHOD given_payload.
    given_masters( ).
    cut->select_master_books( IMPORTING books             = DATA(books)
                                        shortage_language = DATA(shortage) ).
    cl_abap_unit_assert=>assert_initial( shortage ).
    cut->build_payload( EXPORTING books            = books
                        IMPORTING bookstore_create = bookstore_create
                                  book_link        = book_link ).
  ENDMETHOD.
ENDCLASS.

