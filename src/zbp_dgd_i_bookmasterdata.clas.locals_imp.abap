CLASS ltcl_avoid_duplicates DEFINITION DEFERRED FOR TESTING.

CLASS lhc_Book DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltcl_avoid_duplicates.
  PRIVATE SECTION.
    CONSTANTS state_area_duplicates TYPE string VALUE 'AVOID_DUPLICATES'.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Book RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Book RESULT result.
    METHODS avoid_duplicates FOR VALIDATE ON SAVE
      keys FOR Book~avoid_duplicates.

ENDCLASS.


CLASS lhc_Book IMPLEMENTATION.
  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD avoid_duplicates.
    READ ENTITIES OF zdgd_i_bookmasterdata IN LOCAL MODE
         ENTITY Book
         FIELDS ( BookName Author Language )
         WITH CORRESPONDING #( keys )
         RESULT DATA(books).

    IF books IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM zdgd_i_bookmasterdata WITH PRIVILEGED ACCESS
      FIELDS BookID, BookName, Author, Language
      FOR ALL ENTRIES IN @books
      WHERE BookName = @books-BookName
        AND Author   = @books-Author
        AND Language = @books-Language
      INTO TABLE @DATA(potential_duplicates).

    " Instances saved together must not duplicate each other either
    potential_duplicates = CORRESPONDING #( BASE ( potential_duplicates ) books ).

    LOOP AT books INTO DATA(book).
      APPEND VALUE #( %tky        = book-%tky
                      %state_area = state_area_duplicates ) TO reported-book.

      LOOP AT potential_duplicates TRANSPORTING NO FIELDS
           WHERE     BookName  = book-BookName
                 AND Author    = book-Author
                 AND Language  = book-Language
                 AND BookID   <> book-BookID.
        EXIT.
      ENDLOOP.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = book-%tky ) TO failed-book.
      APPEND VALUE #( %tky              = book-%tky
                      %state_area       = state_area_duplicates
                      %msg              = NEW zdgd_book_exception( textid    = zdgd_book_exception=>duplicate_book
                                                                   book_name = book-BookName
                                                                   author    = book-Author
                                                                   language  = book-Language )
                      %element-BookName = if_abap_behv=>mk-on
                      %element-Author   = if_abap_behv=>mk-on
                      %element-Language = if_abap_behv=>mk-on ) TO reported-book.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
