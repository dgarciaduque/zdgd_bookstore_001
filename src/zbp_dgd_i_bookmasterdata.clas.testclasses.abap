*"* use this source file for your ABAP unit test classes
"! @testing BDEF:ZDGD_I_BOOKMASTERDATA
CLASS ltcl_avoid_duplicates DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES active_books TYPE STANDARD TABLE OF zdgd_i_bookmasterdata WITH EMPTY KEY.
    TYPES book_ids     TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    CONSTANTS active_book_id TYPE sysuuid_x16 VALUE '0000000000000000000000000000000A'.

    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.
    CLASS-DATA bo_test_environment  TYPE REF TO if_botd_txbufdbl_bo_test_env.

    DATA cut      TYPE REF TO lhc_book.
    DATA failed   TYPE RESPONSE FOR FAILED LATE zdgd_i_bookmasterdata.
    DATA reported TYPE RESPONSE FOR REPORTED LATE zdgd_i_bookmasterdata.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    METHODS unique_book_passes           FOR TESTING.
    METHODS duplicate_of_active_fails    FOR TESTING.
    METHODS unchanged_own_book_passes    FOR TESTING.
    METHODS other_language_passes        FOR TESTING.
    METHODS two_identical_new_books_fail FOR TESTING.

    METHODS given_active_books
      IMPORTING books TYPE active_books.

    METHODS given_buffer_book
      IMPORTING book_name     TYPE zdgd_bookname
                author        TYPE zdgd_bookauthor
                !language     TYPE spras
      RETURNING VALUE(result) TYPE sysuuid_x16.

    METHODS when_validated
      IMPORTING book_ids TYPE book_ids.

    METHODS count_error_messages
      RETURNING VALUE(result) TYPE i.
ENDCLASS.


CLASS ltcl_avoid_duplicates IMPLEMENTATION.
  METHOD class_setup.
    sql_test_environment = cl_osql_test_environment=>create(
                               i_dependency_list = VALUE #( ( 'ZDGD_I_BOOKMASTERDATA' ) ) ).
    bo_test_environment = cl_botd_txbufdbl_bo_test_env=>create(
        environment_config = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                               )->set_bdef_dependencies( VALUE #( ( 'ZDGD_I_BOOKMASTERDATA' ) ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_test_environment->destroy( ).
    bo_test_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    CREATE OBJECT cut FOR TESTING.
    CLEAR: failed,
           reported.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.                                 "#EC CI_ROLLBACK
    sql_test_environment->clear_doubles( ).
    bo_test_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD unique_book_passes.
    given_active_books( VALUE #( ( bookid   = active_book_id
                                   bookname = 'Other Book'
                                   author   = 'Some Author'
                                   language = 'E' ) ) ).
    DATA(book_id) = given_buffer_book( book_name = 'New Book'
                                       author    = 'Some Author'
                                       language  = 'E' ).

    when_validated( VALUE #( ( book_id ) ) ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_error_messages( ) ).
  ENDMETHOD.

  METHOD duplicate_of_active_fails.
    given_active_books( VALUE #( ( bookid   = active_book_id
                                   bookname = 'Same Book'
                                   author   = 'Same Author'
                                   language = 'E' ) ) ).
    DATA(book_id) = given_buffer_book( book_name = 'Same Book'
                                       author    = 'Same Author'
                                       language  = 'E' ).

    when_validated( VALUE #( ( book_id ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = book_id
                                        act = failed-book[ 1 ]-BookID ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = count_error_messages( ) ).
  ENDMETHOD.

  METHOD unchanged_own_book_passes.
    DATA(book_id) = given_buffer_book( book_name = 'My Book'
                                       author    = 'Me'
                                       language  = 'E' ).
    given_active_books( VALUE #( ( bookid = book_id bookname = 'My Book' author = 'Me' language = 'E' ) ) ).

    when_validated( VALUE #( ( book_id ) ) ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = count_error_messages( ) ).
  ENDMETHOD.

  METHOD other_language_passes.
    given_active_books( VALUE #( ( bookid   = active_book_id
                                   bookname = 'Same Book'
                                   author   = 'Same Author'
                                   language = 'E' ) ) ).
    DATA(book_id) = given_buffer_book( book_name = 'Same Book'
                                       author    = 'Same Author'
                                       language  = 'D' ).

    when_validated( VALUE #( ( book_id ) ) ).

    cl_abap_unit_assert=>assert_initial( failed-book ).
  ENDMETHOD.

  METHOD two_identical_new_books_fail.
    DATA(first_id) = given_buffer_book( book_name = 'Twin'
                                        author    = 'Author'
                                        language  = 'E' ).
    DATA(second_id) = given_buffer_book( book_name = 'Twin'
                                         author    = 'Author'
                                         language  = 'E' ).

    when_validated( VALUE #( ( first_id ) ( second_id ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( failed-book ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = count_error_messages( ) ).
  ENDMETHOD.

  METHOD given_active_books.
    sql_test_environment->insert_test_data( books ).
  ENDMETHOD.

  METHOD given_buffer_book.
    MODIFY ENTITIES OF zdgd_i_bookmasterdata
           ENTITY Book
           CREATE FIELDS ( BookName Author Language )
           WITH VALUE #( ( %cid      = 'BOOK'
                           %is_draft = if_abap_behv=>mk-off
                           BookName  = book_name
                           Author    = author
                           Language  = language ) )
           MAPPED DATA(mapped).

    result = mapped-book[ 1 ]-BookID.
  ENDMETHOD.

  METHOD when_validated.
    cut->avoid_duplicates( EXPORTING keys     = VALUE #( FOR id IN book_ids
                                                         ( %is_draft = if_abap_behv=>mk-off BookID = id ) )
                           CHANGING  failed   = failed
                                     reported = reported ).
  ENDMETHOD.

  METHOD count_error_messages.
    result = REDUCE #( INIT count = 0
                       FOR message IN reported-book WHERE ( %msg IS BOUND )
                       NEXT count = count + 1 ).
  ENDMETHOD.
ENDCLASS.
