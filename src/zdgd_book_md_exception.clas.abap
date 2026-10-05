CLASS zdgd_book_md_exception DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_abap_behv_message.

    CONSTANTS:
      BEGIN OF duplicate_book,
        msgid TYPE symsgid      VALUE 'ZDGD_BOOK_MD',
        msgno TYPE symsgno      VALUE '001',
        attr1 TYPE scx_attrname VALUE 'BOOK_NAME',
        attr2 TYPE scx_attrname VALUE 'AUTHOR',
        attr3 TYPE scx_attrname VALUE 'LANGUAGE',
        attr4 TYPE scx_attrname VALUE '',
      END OF duplicate_book.

    DATA book_name TYPE zdgd_bookname   READ-ONLY.
    DATA author    TYPE zdgd_bookauthor READ-ONLY.
    DATA language  TYPE spras           READ-ONLY.

    METHODS constructor
      IMPORTING textid    TYPE scx_t100key                      OPTIONAL
                !previous TYPE REF TO cx_root                   OPTIONAL
                severity  TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
                book_name TYPE zdgd_bookname                    OPTIONAL
                author    TYPE zdgd_bookauthor                  OPTIONAL
                !language TYPE spras                            OPTIONAL.
ENDCLASS.

CLASS zdgd_book_md_exception IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
    if_abap_behv_message~m_severity = severity.
    me->book_name = book_name.
    me->author    = author.
    me->language  = language.
  ENDMETHOD.
ENDCLASS.
