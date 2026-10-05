CLASS zdgd_populate_bookstore DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS bookstore_count    TYPE i VALUE 20.
    CONSTANTS book_count         TYPE i VALUE 10.
    CONSTANTS books_per_language TYPE i VALUE 2.

    TYPES: BEGIN OF master_book,
             BookID   TYPE sysuuid_x16,
             BookName TYPE zdgd_bookname,
             Author   TYPE zdgd_bookauthor,
             Language TYPE spras,
           END OF master_book,
           master_books TYPE STANDARD TABLE OF master_book WITH EMPTY KEY.
    TYPES language_keys     TYPE STANDARD TABLE OF spras WITH EMPTY KEY.
    TYPES bookstore_creates TYPE TABLE FOR CREATE zdgd_i_bookstore.
    TYPES book_links        TYPE TABLE FOR CREATE zdgd_i_bookstore\_books.
    TYPES book_deletes      TYPE TABLE FOR DELETE zdgd_i_bookstore\\Book.
    TYPES bookstore_deletes TYPE TABLE FOR DELETE zdgd_i_bookstore.
    TYPES mapped_response   TYPE RESPONSE FOR MAPPED zdgd_i_bookstore.
    TYPES failed_response   TYPE RESPONSE FOR FAILED EARLY zdgd_i_bookstore.
    TYPES reported_response TYPE RESPONSE FOR REPORTED EARLY zdgd_i_bookstore.

    METHODS select_master_books
      EXPORTING books             TYPE master_books
                shortage_language TYPE spras.

    METHODS build_payload
      IMPORTING books            TYPE master_books
      EXPORTING bookstore_create TYPE bookstore_creates
                book_link        TYPE book_links.

    METHODS create_entities
      IMPORTING VALUE(bookstore_create) TYPE bookstore_creates
                VALUE(book_link)        TYPE book_links
      EXPORTING !mapped                 TYPE mapped_response
                !failed                 TYPE failed_response
                !reported               TYPE reported_response.

    METHODS is_creation_complete
      IMPORTING !mapped       TYPE mapped_response
                !failed       TYPE failed_response
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS delete_existing
      IMPORTING VALUE(books)  TYPE book_deletes
                VALUE(stores) TYPE bookstore_deletes
      EXPORTING !failed       TYPE failed_response
                !reported     TYPE reported_response.

    METHODS has_existing_entries
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.


CLASS zdgd_populate_bookstore IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    select_master_books( IMPORTING books             = DATA(books)
                                   shortage_language = DATA(shortage_language) ).
    IF shortage_language IS NOT INITIAL.
      out->write( |At least two active master books are required for language { shortage_language }. No data changed.| ).
      RETURN.
    ENDIF.

    build_payload( EXPORTING books            = books
                   IMPORTING bookstore_create = DATA(bookstore_create)
                             book_link        = DATA(book_link) ).

    SELECT BookstoreID FROM zdgd_i_bookstore_d INTO TABLE @DATA(existing_drafts).
    IF existing_drafts IS NOT INITIAL.
      MODIFY ENTITIES OF zdgd_i_bookstore
             ENTITY Bookstore
             EXECUTE Discard FROM VALUE #( FOR draft IN existing_drafts
                                           ( BookstoreID = draft-BookstoreID ) )
             FAILED DATA(discard_failed)
             REPORTED DATA(discard_reported).

      IF discard_failed IS NOT INITIAL.
        ROLLBACK ENTITIES.
        out->write( discard_failed ).
        out->write( discard_reported ).
        RETURN.
      ENDIF.
    ENDIF.

    SELECT BookstoreID, BookID FROM zdgd_i_book INTO TABLE @DATA(existing_books).
    SELECT BookstoreID FROM zdgd_i_bookstore INTO TABLE @DATA(existing_stores).
    delete_existing( EXPORTING books    = CORRESPONDING #( existing_books )
                               stores   = CORRESPONDING #( existing_stores )
                     IMPORTING failed   = DATA(delete_failed)
                               reported = DATA(delete_reported) ).
    IF delete_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      out->write( delete_failed ).
      out->write( delete_reported ).
      RETURN.
    ENDIF.

    IF existing_drafts IS NOT INITIAL OR existing_books IS NOT INITIAL OR existing_stores IS NOT INITIAL.
      COMMIT ENTITIES RESPONSE OF zdgd_i_bookstore
             FAILED DATA(delete_commit_failed)
             REPORTED DATA(delete_commit_reported).
      IF sy-subrc <> 0 OR delete_commit_failed IS NOT INITIAL.
        ROLLBACK ENTITIES.
        out->write( delete_commit_failed ).
        out->write( delete_commit_reported ).
        RETURN.
      ENDIF.
    ENDIF.

    IF has_existing_entries( ) = abap_true.
      out->write( |Cleanup incomplete: bookstore or book records remain. No new entries were inserted.| ).
      RETURN.
    ENDIF.

    create_entities( EXPORTING bookstore_create = bookstore_create
                               book_link        = book_link
                     IMPORTING mapped           = DATA(create_mapped)
                               failed           = DATA(create_failed)
                               reported         = DATA(create_reported) ).

    IF is_creation_complete( mapped = create_mapped
                             failed = create_failed ) = abap_false.
      ROLLBACK ENTITIES.
      out->write( |Creation failed or returned incomplete mappings. No new test data was committed.| ).
      out->write( create_failed ).
      out->write( create_reported ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zdgd_i_bookstore
           FAILED DATA(create_commit_failed)
           REPORTED DATA(create_commit_reported).
    IF sy-subrc <> 0 OR create_commit_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      out->write( create_commit_failed ).
      out->write( create_commit_reported ).
      RETURN.
    ENDIF.

    out->write( |{ lines( create_mapped-bookstore ) } bookstores and { lines( create_mapped-book ) } books created.| ).
  ENDMETHOD.

  METHOD select_master_books.
    CLEAR: books,
           shortage_language.
    DATA(languages) = VALUE language_keys( ( 'E' ) ( 'S' ) ( 'P' ) ( 'I' ) ( 'F' ) ).
    LOOP AT languages INTO DATA(language_key).
      SELECT FROM zdgd_i_bookmasterdata WITH PRIVILEGED ACCESS
        FIELDS BookID, BookName, Author, Language
        WHERE Language = @language_key AND BookID <> @( CONV sysuuid_x16( '' ) )
        ORDER BY BookID
        INTO TABLE @DATA(language_books)
        UP TO @books_per_language ROWS.

      IF lines( language_books ) < books_per_language.
        shortage_language = language_key.
        CLEAR books.
        RETURN.
      ENDIF.
      APPEND LINES OF language_books TO books.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_payload.
    CLEAR: bookstore_create,
           book_link.

    DATA(cities) = VALUE string_table( ( `New York` )
                                       ( `London` )
                                       ( `Paris` )
                                       ( `Tokyo` )
                                       ( `Berlin` )
                                       ( `Rome` )
                                       ( `Madrid` )
                                       ( `Amsterdam` )
                                       ( `Vienna` )
                                       ( `Prague` )
                                       ( `Dublin` )
                                       ( `Edinburgh` )
                                       ( `Barcelona` )
                                       ( `Lisbon` )
                                       ( `Copenhagen` )
                                       ( `Stockholm` )
                                       ( `Sydney` )
                                       ( `Toronto` )
                                       ( `San Francisco` )
                                       ( `Chicago` ) ).

    DATA(bookstore_names) = VALUE string_table( ( `The Reading Nook` )
                                                ( `Paper Trail Books` )
                                                ( `Chapter One` )
                                                ( `Inkwell & Co.` )
                                                ( `The Book Cellar` )
                                                ( `Turning Pages` )
                                                ( `The Literary Attic` )
                                                ( `Bound & Lettered` )
                                                ( `The Dusty Shelf` )
                                                ( `Wordsmith Books` )
                                                ( `The Hidden Library` )
                                                ( `Ink & Paper` )
                                                ( `The Bookworm's Den` )
                                                ( `Storyline Books` )
                                                ( `The Final Chapter` )
                                                ( `Prose & Cons` )
                                                ( `The Book Nook` )
                                                ( `Between the Lines` )
                                                ( `A Novel Idea` )
                                                ( `Quill & Parchment` ) ).

    DO bookstore_count TIMES.
      DATA(cid) = |BS{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.

      APPEND VALUE #( %cid          = cid
                      bookstorename = bookstore_names[ sy-index ]
                      city          = cities[ sy-index ] )
             TO bookstore_create.

      APPEND INITIAL LINE TO book_link ASSIGNING FIELD-SYMBOL(<book_link_row>).
      <book_link_row>-%cid_ref = cid.

      DO book_count TIMES.
        DATA(master) = books[ sy-index ].
        APPEND VALUE #( %cid         = |{ cid }BK{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }|
                        BookID       = master-BookID
                        bookname     = master-BookName
                        author       = master-Author
                        Language     = master-Language
                        UnitsInStock = sy-index * 5 )
               TO <book_link_row>-%target.
      ENDDO.
    ENDDO.
  ENDMETHOD.

  METHOD create_entities.
    MODIFY ENTITIES OF zdgd_i_bookstore
           ENTITY Bookstore
           CREATE FIELDS ( BookstoreName City ) WITH bookstore_create
           CREATE BY \_books FIELDS ( BookID BookName Author Language UnitsInStock ) WITH book_link
           MAPPED mapped
           FAILED failed
           REPORTED reported.
  ENDMETHOD.

  METHOD is_creation_complete.
    result = xsdbool(     failed                    IS INITIAL
                      AND lines( mapped-bookstore )  = bookstore_count
                      AND lines( mapped-book )       = bookstore_count * book_count ).
  ENDMETHOD.

  METHOD delete_existing.
    CLEAR: failed,
           reported.
    IF books IS NOT INITIAL.
      MODIFY ENTITIES OF zdgd_i_bookstore
             ENTITY Book
             DELETE FROM books
             FAILED failed
             REPORTED reported.
      IF failed IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF stores IS NOT INITIAL.
      MODIFY ENTITIES OF zdgd_i_bookstore
             ENTITY Bookstore
             DELETE FROM stores
             FAILED failed
             REPORTED reported.
    ENDIF.
  ENDMETHOD.

  METHOD has_existing_entries.
    result = abap_true.
    " TODO: variable is assigned but never used (ABAP cleaner)
    SELECT SINGLE BookstoreID FROM zdgd_i_bookstore INTO @DATA(store_id).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    " TODO: variable is assigned but never used (ABAP cleaner)
    SELECT SINGLE BookID FROM zdgd_i_book INTO @DATA(book_id).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    SELECT SINGLE BookstoreID FROM zdgd_i_bookstore_d INTO @store_id.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    SELECT SINGLE BookID FROM zdgd_i_book_d INTO @book_id.
    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.
ENDCLASS.

