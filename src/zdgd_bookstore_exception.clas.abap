CLASS zdgd_bookstore_exception DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_abap_behv_message.

    CONSTANTS: BEGIN OF book_not_in_master_data,
                 msgid TYPE symsgid      VALUE 'ZDGD_BOOKSTORE',
                 msgno TYPE symsgno      VALUE '001',
                 attr1 TYPE scx_attrname VALUE '',
                 attr2 TYPE scx_attrname VALUE '',
                 attr3 TYPE scx_attrname VALUE '',
                 attr4 TYPE scx_attrname VALUE '',
               END OF book_not_in_master_data.
    CONSTANTS: BEGIN OF book_already_exists,
                 msgid TYPE symsgid      VALUE 'ZDGD_BOOKSTORE',
                 msgno TYPE symsgno      VALUE '002',
                 attr1 TYPE scx_attrname VALUE '',
                 attr2 TYPE scx_attrname VALUE '',
                 attr3 TYPE scx_attrname VALUE '',
                 attr4 TYPE scx_attrname VALUE '',
               END OF book_already_exists.
    CONSTANTS: BEGIN OF request_contains_duplicates,
                 msgid TYPE symsgid      VALUE 'ZDGD_BOOKSTORE',
                 msgno TYPE symsgno      VALUE '003',
                 attr1 TYPE scx_attrname VALUE '',
                 attr2 TYPE scx_attrname VALUE '',
                 attr3 TYPE scx_attrname VALUE '',
                 attr4 TYPE scx_attrname VALUE '',
               END OF request_contains_duplicates.

    CONSTANTS: BEGIN OF invalid_restock_target,
                 msgid TYPE symsgid      VALUE 'ZDGD_BOOKSTORE',
                 msgno TYPE symsgno      VALUE '004',
                 attr1 TYPE scx_attrname VALUE '',
                 attr2 TYPE scx_attrname VALUE '',
                 attr3 TYPE scx_attrname VALUE '',
                 attr4 TYPE scx_attrname VALUE '',
               END OF invalid_restock_target.
    CONSTANTS: BEGIN OF restock_failed,
                 msgid TYPE symsgid      VALUE 'ZDGD_BOOKSTORE',
                 msgno TYPE symsgno      VALUE '005',
                 attr1 TYPE scx_attrname VALUE '',
                 attr2 TYPE scx_attrname VALUE '',
                 attr3 TYPE scx_attrname VALUE '',
                 attr4 TYPE scx_attrname VALUE '',
               END OF restock_failed.
    CONSTANTS: BEGIN OF no_restock_candidates,
                 msgid TYPE symsgid      VALUE 'ZDGD_BOOKSTORE',
                 msgno TYPE symsgno      VALUE '006',
                 attr1 TYPE scx_attrname VALUE '',
                 attr2 TYPE scx_attrname VALUE '',
                 attr3 TYPE scx_attrname VALUE '',
                 attr4 TYPE scx_attrname VALUE '',
               END OF no_restock_candidates.
    METHODS constructor
      IMPORTING textid    LIKE if_t100_message=>t100key         OPTIONAL
                !previous LIKE previous                         OPTIONAL
                severity  TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zdgd_bookstore_exception IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = book_not_in_master_data.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
    if_abap_behv_message~m_severity = severity.
  ENDMETHOD.
ENDCLASS.

