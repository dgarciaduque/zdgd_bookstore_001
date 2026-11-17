CLASS zdgd_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZDGD_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    SELECT FROM zdgd_i_bookstore
      FIELDS *
      INTO TABLE @DATA(bookstores).

    out->write( bookstores ).
  ENDMETHOD.
ENDCLASS.
