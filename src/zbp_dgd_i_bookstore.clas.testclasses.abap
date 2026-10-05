*"* use this source file for your ABAP unit test classes
CLASS ltcl_book_master_data DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES master_books TYPE STANDARD TABLE OF zdgd_i_bookmasterdata WITH EMPTY KEY.
    TYPES draft_books  TYPE STANDARD TABLE OF zdgd_i_bookmasterdata_d WITH EMPTY KEY.

    CONSTANTS master_book_id  TYPE sysuuid_x16 VALUE '00000000000000000000000000000002'.
    CONSTANTS missing_book_id TYPE sysuuid_x16 VALUE '00000000000000000000000000000003'.

    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.
    CLASS-DATA bo_test_environment  TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA cut       TYPE REF TO lhc_book.
    DATA book_keys TYPE TABLE FOR READ IMPORT zdgd_i_bookstore\\Book.
    DATA failed    TYPE RESPONSE FOR FAILED LATE zdgd_i_bookstore.
    DATA reported  TYPE RESPONSE FOR REPORTED LATE zdgd_i_bookstore.

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
    METHODS draft_details_mismatch         FOR TESTING.

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

    METHODS when_validated.
    METHODS count_errors RETURNING VALUE(result) TYPE i.
ENDCLASS.


CLASS ltcl_book_master_data IMPLEMENTATION.
  METHOD class_setup.
    sql_test_environment = cl_osql_test_environment=>create(
                               i_dependency_list = VALUE #( ( 'ZDGD_I_BOOKMASTERDATA' )
                                                            ( 'ZDGD_I_BOOKMASTERDATA_D' ) ) ).
    bo_test_environment = cl_botd_txbufdbl_bo_test_env=>create(
                              environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                               )->set_bdef_dependencies( VALUE #( ( 'ZDGD_I_BOOKSTORE' ) ) ) ).
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
    cl_abap_unit_assert=>assert_equals( exp = 'BOOK_MASTER_DATA'
                                        act = error-%state_area ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
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
  ENDMETHOD.

  METHOD draft_details_mismatch.
    given_master_details( ).
    given_book( book_id   = master_book_id
                is_draft  = if_abap_behv=>mk-on
                book_name = 'Master Book'
                author    = 'Master Author'
                language  = 'F' ).
    when_validated( ).
    assert_mismatch( language_flag = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on
                                        act = failed-book[ 1 ]-%is_draft ).
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
    cut->validate_book_master_data( EXPORTING keys     = CORRESPONDING #( book_keys )
                                    CHANGING  failed   = failed
                                              reported = reported ).
  ENDMETHOD.

  METHOD count_errors.
    result = REDUCE #( INIT count = 0
             FOR message IN reported-book WHERE ( %msg IS BOUND )
             NEXT count = count + 1 ).
  ENDMETHOD.
ENDCLASS.

