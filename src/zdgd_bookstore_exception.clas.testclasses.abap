*"* use this source file for your ABAP unit test classes
CLASS ltcl_bookstore_exception DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS default_message       FOR TESTING.
    METHODS explicit_message      FOR TESTING.
    METHODS custom_textid         FOR TESTING.
    METHODS custom_severity       FOR TESTING.
    METHODS previous_is_preserved FOR TESTING.
ENDCLASS.


CLASS ltcl_bookstore_exception IMPLEMENTATION.
  METHOD default_message.
    DATA(message) = NEW zdgd_bookstore_exception( ).
    DATA(expected_key) = VALUE scx_t100key( msgid = 'ZDGD_BOOKSTORE'
                                            msgno = '001' ).

    cl_abap_unit_assert=>assert_equals( exp = expected_key
                                        act = message->if_t100_message~t100key ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv_message=>severity-error
                                        act = message->if_abap_behv_message~m_severity ).
  ENDMETHOD.

  METHOD explicit_message.
    DATA(message) = NEW zdgd_bookstore_exception( textid = zdgd_bookstore_exception=>book_not_in_master_data ).
    DATA rap_message TYPE REF TO if_abap_behv_message.
    rap_message = message.
    DATA(expected_key) = VALUE scx_t100key( msgid = 'ZDGD_BOOKSTORE'
                                            msgno = '001' ).

    cl_abap_unit_assert=>assert_equals( exp = expected_key
                                        act = message->if_t100_message~t100key ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv_message=>severity-error
                                        act = rap_message->m_severity ).
  ENDMETHOD.

  METHOD custom_textid.
    DATA(expected_key) = VALUE scx_t100key( msgid = 'ZDGD_BOOKSTORE'
                                            msgno = '002' ).
    DATA(message) = NEW zdgd_bookstore_exception( textid = expected_key ).

    cl_abap_unit_assert=>assert_equals( exp = expected_key
                                        act = message->if_t100_message~t100key ).
  ENDMETHOD.

  METHOD custom_severity.
    DATA(message) = NEW zdgd_bookstore_exception( severity = if_abap_behv_message=>severity-warning ).

    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv_message=>severity-warning
                                        act = message->if_abap_behv_message~m_severity ).
  ENDMETHOD.

  METHOD previous_is_preserved.
    DATA(previous) = NEW zdgd_bookstore_exception( ).
    DATA(message) = NEW zdgd_bookstore_exception( previous = previous ).

    cl_abap_unit_assert=>assert_equals( exp = previous
                                        act = message->previous ).
  ENDMETHOD.
ENDCLASS.
